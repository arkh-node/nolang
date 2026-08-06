#!/usr/bin/env bash
# anchor_verify — пересчитать заякоренный отпечаток из ЭТОГО дерева и сверить с ANCHORS.md.
#
# 🔴 ЗАЧЕМ ОТДЕЛЬНЫЙ СКРИПТ, А НЕ СТРОЧКА В БАТАРЕЕ.
# Якорь имеет смысл ровно постольку, поскольку его может проверить ПОСТОРОННИЙ — тот, кто нам
# не верит. Значит проверка обязана запускаться одной командой сразу после `git clone`, без
# чтения исходников и без веры в наши слова. Опубликованное число, которое никто не умеет
# пересчитать, — не свидетельство, а украшение.
#
# 🔴 ЧТО ЗНАЧИТ РАСХОЖДЕНИЕ. Что записанный субъект больше не воспроизводится из текущего
# дерева. Это либо переписанное прошлое, либо честное изменение языка. **Различить их скрипт
# не может и не притворяется**: он докладывает расхождение и останавливается. Честное изменение
# закрывается ДОБАВЛЕНИЕМ нового якоря, а не правкой старого — иначе теряется ровно то, ради
# чего строка публикуется.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"

ANCHORS="$ROOT/ANCHORS.md"
[ -f "$ANCHORS" ] || { echo "❌ ANCHORS.md не найден — сверять не с чем"; exit 1; }

command -v sbcl >/dev/null 2>&1 || {
  echo "❌ sbcl не найден — пересчитать отпечаток нечем."
  echo "   Это НЕ «якорь сошёлся», это невозможность проверки. Код возврата 1."
  exit 1
}

# Записанные значения берём из таблицы — первый sha256 в строке якоря №1.
want_subj=$(grep -oE 'sha256:[0-9a-f]{64}' "$ANCHORS" | head -1)
want_scene=$(grep -oE 'sha256:[0-9a-f]{64}' "$ANCHORS" | sed -n '2p')
[ -n "$want_subj" ] || { echo "❌ в ANCHORS.md нет записанного отпечатка"; exit 1; }

{ echo "(defparameter *root* \"$ROOT/\")"; cat <<'LISP'
(load (merge-pathnames "src/nolang.lisp" *root*))
(load (merge-pathnames "src/subject.lisp" *root*))
(defun slurp (p) (with-open-file (s p :external-format :utf-8)
  (let ((o (make-string-output-stream)))
    (loop for l = (read-line s nil nil) while l do (write-line l o))
    (get-output-stream-string o))))
(defparameter *d* (merge-pathnames "test/subject/" *root*))
(defparameter *f* (parse (concatenate 'string (slurp (merge-pathnames "scene.nolp" *d*))
                                              (slurp (merge-pathnames "trace.nol" *d*)))))
;; 🔴 Носитель задаётся ЯВНО и входит в отпечаток. Иначе тот же субъект на другой машине дал бы
;; другое число, и якорь стал бы непроверяемым у всех, кроме нас, — то есть перестал быть якорем.
(defparameter *s* (with-prelude (multiple-value-bind (st lg) (run-nolang *f* :carrier :морф)
                    (declare (ignore st)) (serialize-subject *f* lg :carrier :морф))))
(format t "~a~%~a~%" (subject-digest *s*) (subject-scene-digest *s*))
LISP
} > /tmp/nol_anchor_verify.lisp

out=$(sbcl --script /tmp/nol_anchor_verify.lisp 2>&1); rc=$?
rm -f /tmp/nol_anchor_verify.lisp
if [ $rc -ne 0 ]; then
  echo "❌ пересчёт не отработал (код $rc):"; echo "$out" | head -5 | sed 's/^/   /'; exit 1
fi

got_subj=$(echo "$out" | sed -n '1p')
got_scene=$(echo "$out" | sed -n '2p')

ok=0
if [ "$got_subj" = "$want_subj" ]; then
  echo "✓ субъект   сошёлся: $got_subj"
else
  echo "❌ СУБЪЕКТ НЕ СОШЁЛСЯ"
  echo "   записано: $want_subj"
  echo "   получено: $got_subj"
  ok=1
fi
if [ -n "$want_scene" ]; then
  if [ "$got_scene" = "$want_scene" ]; then
    echo "✓ сцена     сошлась: $got_scene"
  else
    echo "❌ СЦЕНА НЕ СОШЛАСЬ (изменилось то, ЧЕМ судят)"
    echo "   записано: $want_scene"
    echo "   получено: $got_scene"
    ok=1
  fi
fi

if [ $ok -eq 0 ]; then
  echo
  echo "Якорь сошёлся. Это значит: заякоренный субъект воспроизводится из этого дерева."
  echo "Это НЕ значит «подделка невозможна» — см. ANCHORS.md, раздел о границах."
else
  echo
  echo "Расхождение. Либо прошлое переписано, либо язык честно изменился — скрипт различить"
  echo "их не может. Честное изменение закрывается ДОБАВЛЕНИЕМ якоря, а не правкой строки."
fi
exit $ok
