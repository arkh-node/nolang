#!/bin/bash
# D6_anchor — внешний якорь цепи субъектов (06.08.2026).
#
# 🔴 ЧТО ЗДЕСЬ ПРОВЕРЯЕТСЯ, А ЧТО ПРОВЕРИТЬ НЕЛЬЗЯ.
# Якорь утверждает: «этот отпечаток лежит вон там, снаружи». Что он там ДЕЙСТВИТЕЛЬНО лежит —
# утверждение о мире, и батарея его не проверяет и проверить не может: она не ходит в сеть и
# не должна. Проверяется вычислимая часть — сходится ли якорь с цепью, правильно ли считается
# сила канала, и ГДЕ проходит граница защищённого.
#
# 🔴 И отдельно проверяется то, чего якорь НЕ ДАЁТ. Батарея, показывающая только выигрыш,
# продаёт лекарство: проверка №6 требует, чтобы подделка ПОСЛЕ последнего якоря прошла
# незамеченной — потому что она и должна проходить, и знать об этом важнее, чем радоваться
# первым пяти галочкам.
cd "$(dirname "$0")/.." || exit 1
# 🔴 Корень берётся ОТ СКРИПТА, а не зашит: генерируемый лисп живёт в /tmp, и его
# *load-pathname* указывает туда же — относительные пути внутри него не сработают.
ROOT="$(pwd)"
ok=0; fail=0

{ echo "(defparameter *root* \"$ROOT/\")"; cat <<'LISP'
(load (merge-pathnames "src/nolang.lisp" *root*))
(load (merge-pathnames "src/subject.lisp" *root*))
(load (merge-pathnames "src/anchor.lisp" *root*))
(defun chk (c m) (format t "~&~a ~a~%" (if c "OK" "FAIL") m))
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))

(defparameter *dir* (merge-pathnames "test/subject/" *root*))
(defparameter *f* (parse (concatenate 'string (slurp (merge-pathnames "scene.nolp" *dir*))
                                              (slurp (merge-pathnames "trace.nol" *dir*)))))

(defun mk (prev)
  (with-prelude (multiple-value-bind (st lg) (run-nolang *f* :carrier :морф)
                  (declare (ignore st))
                  (serialize-subject *f* lg :carrier :морф :prev prev))))

;; Цепь из трёх звеньев: каждое несёт отпечаток предыдущего.
(defparameter *s0* (mk nil))
(defparameter *s1* (mk (subject-digest *s0*)))
(defparameter *s2* (mk (subject-digest *s1*)))
(defparameter *chain* (list *s0* *s1* *s2*))

(multiple-value-bind (ok) (chain-verify *chain*)
  (chk ok "предпосылка: честная цепь из трёх звеньев сходится"))

;; ── 1. СИЛА СЧИТАЕТСЯ ПО КАНАЛУ, А НЕ ПО ОБЪЯВЛЕНИЮ ───────────────────────────
;; Тот же закон, что для источников: степень не поднимается объявлением.
(let ((a (make-anchor "sha256:x" :file "путь" :declared :notarised)))
  (chk (and (eq :self (anchor-class-of a)) (anchor-lowered-p a))
       "объявленный :notarised для файла на своём диске понижен до :self, и понижение записано"))

(let ((a (make-anchor "sha256:x" :public-repo "commit abc123")))
  (chk (eq :witnessed (anchor-class-of a))
       "публичный репозиторий даёт :witnessed без объявления"))

(let ((a (make-anchor "sha256:x" :public-repo "commit abc" :declared :self)))
  (chk (eq :self (anchor-class-of a))
       "объявить силу НИЖЕ канала можно: встреча берёт слабейшее"))

;; ── 2. :self — НЕ ЯКОРЬ, И ЭТО ОТКАЗ, А НЕ ПРИМЕЧАНИЕ ─────────────────────────
(let ((a (make-anchor (subject-digest *s1*) :file "/tmp/наш_файл")))
  (multiple-value-bind (ok i why) (anchor-verify a *chain*)
    (declare (ignore i))
    (chk (and (not ok) (eq why :no-strength))
         ":self отвергается как якорь, хотя отпечаток сходится (предъявляем самим себе)")))

;; ── 3. ЧЕСТНЫЙ ЯКОРЬ СХОДИТСЯ И НАХОДИТ СВОЁ МЕСТО ────────────────────────────
(defparameter *a1* (make-anchor (subject-digest *s1*) :public-repo "commit 17107b3"))
(multiple-value-bind (ok i why) (anchor-verify *a1* *chain*)
  (declare (ignore why))
  (chk (and ok (= i 1)) "якорь на второе звено сходится и указывает индекс 1"))

;; ── 4. ГРАНИЦА ЗАЩИЩЁННОГО — ЧИСЛОМ ───────────────────────────────────────────
(multiple-value-bind (safe total class) (chain-anchored-prefix *chain* (list *a1*))
  (chk (and (= safe 2) (= total 3) (eq class :witnessed))
       "защищено 2 из 3 звеньев, сила :witnessed — сказано счётом, а не оговоркой"))

;; Якорь на последнее звено закрывает цепь целиком.
(let ((a2 (make-anchor (subject-digest *s2*) :timestamped "метка времени")))
  (multiple-value-bind (safe total class) (chain-anchored-prefix *chain* (list *a1* a2))
    (chk (and (= safe 3) (= total 3) (eq class :notarised))
         "якорь на последнее звено: защищено 3 из 3, сила :notarised")))

;; ── 5. 🔴 ПОДДЕЛКА ВНУТРИ ЗАЯКОРЕННОГО ОТРЕЗКА — ЛОВИТСЯ ──────────────────────
(let* ((bad0 (copy-tree *s0*))
       (_ (setf (getf (cddr bad0) :seal) '((:ran-on :морф nil) (:performed publish c 0.99 0.9))))
       (bad-chain (list bad0 *s1* *s2*)))
  (declare (ignore _))
  ;; сама цепь тоже рвётся — но нас интересует ИМЕННО якорь: он ловит подделку,
  ;; даже если бы противник аккуратно перестроил всю цепь под себя.
  (let ((a0 (make-anchor (subject-digest *s0*) :public-repo "commit до подделки")))
    (multiple-value-bind (ok i why) (anchor-verify a0 bad-chain)
      (declare (ignore i))
      (chk (and (not ok) (eq why :not-in-chain))
           "подделка звена внутри заякоренного отрезка — якорь не сходится"))))

;; 🔴 И ГЛАВНОЕ: подделка ловится даже при ПОЛНОСТЬЮ ПЕРЕСТРОЕННОЙ цепи, то есть там,
;; где chain-verify бессилен. Ровно ради этого случая якорь и заводился.
(let* ((bad0 (copy-tree *s0*))
       (_ (setf (getf (cddr bad0) :seal) '((:ran-on :морф nil))))
       (b1 (mk (subject-digest bad0)))
       (b2 (mk (subject-digest b1)))
       (rebuilt (list bad0 b1 b2))
       (a0 (make-anchor (subject-digest *s0*) :public-repo "commit до подделки")))
  (declare (ignore _))
  (multiple-value-bind (chain-ok) (chain-verify rebuilt)
    (chk chain-ok "перестроенная подделка ВНУТРЕННЕ СВЯЗНА — chain-verify её пропускает"))
  (multiple-value-bind (ok i why) (anchor-verify a0 rebuilt)
    (declare (ignore i))
    (chk (and (not ok) (eq why :not-in-chain))
         "🔴 и ровно её ловит якорь — то, чего цепь не может в принципе")))

;; ── 6. 🔴 ЧЕГО ЯКОРЬ НЕ ДАЁТ — ПРОВЕРЯЕТСЯ НАРАВНЕ С ТЕМ, ЧТО ДАЁТ ────────────
;; Подделка ПОСЛЕ последнего якоря им не ловится. Это не дефект: якорь свидетельствует о
;; прошлом, а не о будущем. Проверка стоит здесь, чтобы граница была не словом, а строкой.
(let* ((bad2 (copy-tree *s2*))
       (_ (setf (getf (cddr bad2) :seal) '((:ran-on :морф nil))))
       (chain2 (list *s0* *s1* bad2)))
  (declare (ignore _))
  (multiple-value-bind (ok) (anchor-verify *a1* chain2)
    (chk ok "подделка ПОСЛЕ якоря им НЕ ловится — граница названа проверкой, а не оговоркой"))
  (multiple-value-bind (safe total) (chain-anchored-prefix chain2 (list *a1*))
    (chk (and (= safe 2) (= total 3))
         "и отчёт честно показывает: 1 звено вне защиты")))

;; ── 7. КОНТРОЛЬ ПРОТИВ ЛОЖНОГО СТОРОЖА ────────────────────────────────────────
;; Если бы anchor-verify отказывал всегда, проверки 5 и 6 были бы зелёными зря.
(multiple-value-bind (ok) (anchor-verify *a1* *chain*)
  (chk ok "контроль: на честной цепи тот же якорь проходит"))

;; Отчёт печатается и называет незащищённое.
(let ((r (anchor-report *chain* (list *a1*))))
  (chk (and (search "2 из 3" r) (search "НЕ защищено" r))
       "отчёт называет незащищённую часть вслух"))
LISP
} > /tmp/nol_d6.lisp
out=$(sbcl --script /tmp/nol_d6.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   echo "  ✓ ${line#OK }"; ok=$((ok+1));;
    FAIL*) echo "  ✗ ${line#FAIL }"; fail=1;;
  esac
done <<< "$out"
if echo "$out" | grep -q "Unhandled"; then
  echo "  ✗ необработанная ошибка"; echo "$out" | grep -m2 -A3 "Unhandled" | sed 's/^/    /'; fail=1
fi
rm -f /tmp/nol_d6.lisp
echo "ИТОГ: $ok"
exit $fail
