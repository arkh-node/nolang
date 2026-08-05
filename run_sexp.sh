#!/usr/bin/env bash
# Прогон программы РАННЕГО СЛОЯ (s-выражения, `src/nol.lisp`): examples/sexp/*.nol
#
# 🔴 ЭТОТ НОСИТЕЛЬ НЕ ВЫНОСИТ ВЕРДИКТА, и потому кодов у него два, а не шесть:
#     0 — прогон состоялся · 2 — сбой инструмента.
# Ранний слой ВЫЧИСЛЯЕТ (трёхзначный гейт на атомах `(f,c)`), а не решает о необратимом:
# у него нет ни решётки степеней, ни массы веры по корням, ни журнала последствий.
# Выдавать здесь «0 = допущено» значило бы сказать про язык то, чего он не говорит, —
# ровно ту ложь инструмента, против которой заведён этап 1.
set -u
cd "$(dirname "$0")" || exit 2

F="${1:?укажите файл .nol из examples/sexp/}"
if [ ! -r "$F" ]; then
  printf '⛔ файл не читается: %s\n' "$F" >&2
  exit 2
fi

RUNNER=/tmp/_nol_sexp.lisp
cat > "$RUNNER" <<'LISP'
(load (merge-pathnames "src/nol.lisp" (or (sb-ext:posix-getenv "NOL_HOME") "")))
(handler-case
    (progn (run-nol (sb-ext:posix-getenv "NOL_PROGRAM"))
           (format t "~&⟦NOLANG-SEXP code=0⟧ прогон состоялся (вердикта этот носитель не выносит)~%")
           (finish-output)
           (sb-ext:exit :code 0))
  (error (e)
    (format t "~&── СБОЙ ИНСТРУМЕНТА ──~%~a~%⟦NOLANG-SEXP code=2⟧ судить не удалось~%" e)
    (finish-output)
    (sb-ext:exit :code 2)))
LISP

NOL_HOME="$(pwd)/" NOL_PROGRAM="$F" sbcl --script "$RUNNER"
