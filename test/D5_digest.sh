#!/bin/bash
# D5_digest — криптографический отпечаток (06.08.2026).
#
# 🔴 ЗАЧЕМ ЭТА БАТАРЕЯ ОТДЕЛЬНАЯ И ПОЧЕМУ ОНА ШЕЛЛ.
# SHA-256 написан в этом репозитории руками (`src/digest.lisp`) — библиотеки нет, чтобы
# чистый клон собирался без установки чего бы то ни было. Плата за это ровно одна:
# СВОЯ реализация криптографии стоит РОВНО СТОЛЬКО, СКОЛЬКО ОНА СВЕРЕНА С ЧУЖОЙ.
# Несверенная выглядела бы криптографической, не будучи ею, — то есть была бы ХУЖЕ
# честного `sxhash`, который хотя бы не притворяется.
#
# Сверка возможна только СНАРУЖИ процесса: эталон — системный `sha256sum` и `python3`,
# оба отдельные программы. Тест, живущий внутри Лиспа, сверил бы нашу реализацию сама
# с собой — тот же род ошибки, что поймал нас 05.08 (тест сверял две функции между собой,
# а портились они одинаково).
#
# 🔴 ЕСЛИ ЭТАЛОНА НЕТ НА МАШИНЕ — батарея говорит это ВСЛУХ и роняет счёт, а не тихо
# пропускает. Пропущенная сверка, не отличимая от пройденной, есть тот самый сломанный
# сторож, который рапортует «спокойно» от слепоты.
cd "$(dirname "$0")/.." || exit 1
ok=0; fail=0
say_ok()   { echo "  ✓ $1"; ok=$((ok+1)); }
say_fail() { echo "  ✗ $1"; fail=1; }

# ── 0. ЭТАЛОН ЕСТЬ? ─────────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
  echo "  ✗ ЭТАЛОНА НЕТ: python3 отсутствует — сверить свою реализацию SHA-256 не с чем."
  echo "    Батарея НЕ пройдена. Это не поломка машины, это отсутствие права утверждать,"
  echo "    что наш отпечаток есть SHA-256."
  echo "ИТОГ: 0"
  exit 1
fi

# ── 1. ДИФФ-ТЕСТ ПРОТИВ ЭТАЛОНА ─────────────────────────────────────────────
# Входы выбраны не «для красоты», а по местам, где ломаются самодельные реализации:
# пустая строка · границы блока 55/56/63/64/65 байт (дополнение переползает в новый блок) ·
# многобайтный UTF-8 (кодировка, а не хеш) · длинный вход (расписание сообщения).
INPUTS_PY='["", "abc",
 "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
 "Аристарх", "(horizon 3) (lattice provenance = design * transmission)",
 "a"*55, "a"*56, "a"*63, "a"*64, "a"*65, "я"*1000, "\x00\x01\x7f"]'

cat > /tmp/nol_d5_mine.lisp <<'LISP'
(load "/srv/langs/nolang/src/digest.lisp")
(dolist (s (list "" "abc"
                 "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
                 "Аристарх"
                 "(horizon 3) (lattice provenance = design * transmission)"
                 (make-string 55 :initial-element #\a)
                 (make-string 56 :initial-element #\a)
                 (make-string 63 :initial-element #\a)
                 (make-string 64 :initial-element #\a)
                 (make-string 65 :initial-element #\a)
                 (make-string 1000 :initial-element #\я)
                 (coerce (list (code-char 0) (code-char 1) (code-char 127)) 'string)))
  (format t "~a~%" (sha256-hex s)))
LISP

sbcl --script /tmp/nol_d5_mine.lisp > /tmp/nol_d5_mine.txt 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  say_fail "своя реализация не отработала (код $rc)"
  sed 's/^/    /' /tmp/nol_d5_mine.txt | head -5
  echo "ИТОГ: $ok"; exit 1
fi

python3 -c "
import hashlib
for s in $INPUTS_PY: print(hashlib.sha256(s.encode('utf-8')).hexdigest())
" > /tmp/nol_d5_ref.txt 2>&1

if diff -q /tmp/nol_d5_mine.txt /tmp/nol_d5_ref.txt >/dev/null 2>&1; then
  n=$(wc -l < /tmp/nol_d5_mine.txt)
  say_ok "дифф-тест против эталона: $n/$n совпало (границы блока, UTF-8, управляющие)"
else
  say_fail "РАСХОЖДЕНИЕ С ЭТАЛОНОМ — наша реализация НЕ есть SHA-256:"
  diff /tmp/nol_d5_mine.txt /tmp/nol_d5_ref.txt | head -6 | sed 's/^/    /'
fi

# Второй, независимый эталон: sha256sum из coreutils. Две разные реализации лучше одной —
# совпадение с обеими исключает общий источник ошибки (обе от нас не зависят).
if command -v sha256sum >/dev/null 2>&1; then
  a=$(printf 'abc' | sha256sum | cut -d' ' -f1)
  b=$(sed -n '2p' /tmp/nol_d5_mine.txt)
  if [ "$a" = "$b" ]; then
    say_ok "второй независимый эталон (coreutils sha256sum) согласен"
  else
    say_fail "coreutils не согласен: $a ≠ $b"
  fi
else
  echo "  ⚠ sha256sum отсутствует — второй эталон не проверен (сказано вслух, не скрыто)"
fi

# ── 2. СВОЙСТВА, РАДИ КОТОРЫХ МЕНЯЛИ sxhash ─────────────────────────────────
cat > /tmp/nol_d5_prop.lisp <<'LISP'
(load "/srv/langs/nolang/src/digest.lisp")
(defun chk (c m) (format t "~&~a ~a~%" (if c "OK" "FAIL") m))

;; Лавина: один изменённый знак меняет отпечаток целиком, а не хвост.
(let* ((x (sha256-hex "источник abstract"))
       (y (sha256-hex "источник abstracu"))
       (same (loop for i from 0 below 64 count (char= (char x i) (char y i)))))
  (chk (and (string/= x y) (< same 20))
       (format nil "лавина: один знак — ~a/64 позиций совпало (случайно ожидается ~~4)" same)))

;; Ширина 256 бит: 64 знака, все шестнадцатеричные.
(let ((h (sha256-hex "что угодно")))
  (chk (and (= 64 (length h))
            (every (lambda (c) (find c "0123456789abcdef")) h))
       "ширина 256 бит, нижний регистр, только hex"))

;; Детерминизм в пределах запуска.
(chk (string= (sha256-hex "повтор") (sha256-hex "повтор")) "одна строка — один отпечаток")

;; Отпечаток НЕСЁТ ИМЯ АЛГОРИТМА. Без него смена функции сделала бы старые записи
;; неотличимыми от испорченных.
(let ((d (digest-string "x")))
  (chk (and (> (length d) 7) (string= "sha256:" (subseq d 0 7)))
       "отпечаток записи несёт имя алгоритма: sha256:<hex>"))

;; UTF-8 считается по КОДОВЫМ ТОЧКАМ, а не по знакам: длина байтов ≠ длина строки.
(chk (= 2 (length (utf8-octets "я"))) "кириллическая буква — два байта UTF-8")
(chk (= 4 (length (utf8-octets (string (code-char #x1F600)))))
     "символ вне BMP — четыре байта UTF-8")

;; 🔴 ГЛАВНОЕ: отпечаток не зависит от НОСИТЕЛЯ. Проверяемо здесь только косвенно —
;; тем, что он не берётся из sxhash и не зависит от внешнего формата потока: строка
;; кодируется своим кодировщиком. Прямая проверка — прогон на другой машине; она в
;; ведении оператора, и здесь об этом сказано, а не умолчано.
(chk (string= (sha256-hex "переносимость")
              (let ((*print-pretty* t)) (sha256-hex "переносимость")))
     "отпечаток не зависит от настроек печати процесса")
LISP

out=$(sbcl --script /tmp/nol_d5_prop.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   say_ok "${line#OK }";;
    FAIL*) say_fail "${line#FAIL }";;
  esac
done <<< "$out"
echo "$out" | grep -q "Unhandled" && say_fail "свойства: необработанная ошибка"

# ── 3. ПРОВЕРКА НА РАЗЛИЧЕНИИ: ЛОВИТ ЛИ ПОДДЕЛКУ ────────────────────────────
# 🔴 Сторож, не пойманный на искусственной поломке, — талисман, а не сторож.
# Подсовываем цепи субъектов подделанное звено и требуем, чтобы она порвалась.
cat > /tmp/nol_d5_tamper.lisp <<'LISP'
(load "/srv/langs/nolang/src/nolang.lisp")
(load "/srv/langs/nolang/src/subject.lisp")
(defun chk (c m) (format t "~&~a ~a~%" (if c "OK" "FAIL") m))

;; Сцена и след берутся из ЖИВОГО примера (test/subject/), а не сочиняются здесь.
;; Сочинённая программа проверяла бы синтаксис, который я помню, а не тот, что в языке.
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))

(defun replace-sub (s old new)
  (let ((i (search old s)))
    (if i (concatenate 'string (subseq s 0 i) new (subseq s (+ i (length old)))) s)))

(defparameter *dir* "/srv/langs/nolang/test/subject/")
(defparameter *scene-src* (slurp (merge-pathnames "scene.nolp" *dir*)))
(defparameter *trace-src* (slurp (merge-pathnames "trace.nol" *dir*)))
(defparameter *f* (parse (concatenate 'string *scene-src* *trace-src*)))

(defparameter *s1*
  (with-prelude (multiple-value-bind (st lg) (run-nolang *f* :carrier :морф)
                  (declare (ignore st)) (serialize-subject *f* lg :carrier :морф))))

;; Версия записи поднята — старые записи должны опознаваться как ДРУГИЕ, а не как порча.
(chk (= 3 (getf *s1* :subject)) "версия записи субъекта — 3 (отпечатки sha256)")

;; Отпечаток сцены действительно криптографический, а не машинное слово.
(let ((sd (getf (cddr *s1*) :scene-digest)))
  (chk (and sd (string= "sha256:" (subseq sd 0 7)) (= 71 (length sd)))
       "отпечаток сцены: sha256:<64 знака>"))

;; 🔴 ПОДДЕЛКА СЦЕНЫ, НЕ МЕНЯЮЩАЯ ВЫВОД. Ровно тот случай, что прошёл незамеченным
;; 05.08 и заставил завести отдельный отпечаток сцены: класс источника поднят, но
;; свидетель как был abstract, так и остался, — журнал совпадает, воспроизведение молчит.
;; Отпечаток обязан поймать это ПРЯМО.
;; 🔴 КОНТРОЛЬ ПРОТИВ ЛОЖНОГО СТОРОЖА. Проверка «подмена поймана» ничего не стоит, если
;; возврат отказывает ВСЕГДА. Подставляем сцену тем же способом, но НЕ меняя её, и требуем,
;; чтобы возврат прошёл. Без этой строки следующая проверка могла бы быть зелёной по
;; неверной причине — ровно та ошибка, что случилась 05.08 (мутация не поймалась, потому
;; что тест сверял две одинаково испорченные величины).
(let ((same (copy-tree *s1*)))
  (setf (getf (cddr same) :scene) (scene-forms (parse *scene-src*)))
  (multiple-value-bind (ok lg why) (re-enter same)
    (declare (ignore lg))
    (chk (and ok (null why)) "контроль: та же сцена тем же способом — возврат проходит")))

;; Поднимаем класс источника abstracts до published. Свидетель `honest` как был
;; (randomised, abstract), так и остаётся — потолок лишь стал выше, ничего не пережало.
;; Значит журнал совпадёт, воспроизведение промолчит, и поймать это может ТОЛЬКО
;; прямой отпечаток сцены.
(let ((bad (copy-tree *s1*)))
  (setf (getf (cddr bad) :scene)
        (scene-forms (parse (replace-sub *scene-src*
                                         "abstracts  : (randomised, abstract)"
                                         "abstracts  : (randomised, published)"))))
  (multiple-value-bind (ok lg why) (re-enter bad)
    (declare (ignore lg))
    (chk (and (not ok) why) "подмена сцены, НЕ меняющая вывод — поймана отпечатком")))

;; Подмена ОДНОГО ЗНАКА в отпечатке источника обязана менять отпечаток сцены.
;; Это то, чего `sxhash` не гарантировал: у машинного слова столкновение подбирается.
(let* ((f2 (parse (concatenate 'string
                    (replace-sub *scene-src* "doi:10.1136/bmj.g2545" "doi:10.1136/bmj.g2546")
                    *trace-src*)))
       (s2 (with-prelude (multiple-value-bind (st lg) (run-nolang f2 :carrier :морф)
                           (declare (ignore st)) (serialize-subject f2 lg :carrier :морф)))))
  (chk (string/= (getf (cddr *s1*) :scene-digest) (getf (cddr s2) :scene-digest))
       "один знак в fingerprint источника — другой отпечаток сцены"))
LISP

out=$(sbcl --script /tmp/nol_d5_tamper.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   say_ok "${line#OK }";;
    FAIL*) say_fail "${line#FAIL }";;
  esac
done <<< "$out"
echo "$out" | grep -q "Unhandled" && { say_fail "различение: необработанная ошибка"; echo "$out" | grep -m2 -A2 "Unhandled" | sed 's/^/    /'; }

rm -f /tmp/nol_d5_*.lisp /tmp/nol_d5_*.txt
echo "ИТОГ: $ok"
exit $fail
