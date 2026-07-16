#!/bin/bash
# smoke-runner: гоняет тесты трёх камней, проверяет ключевые маркеры. НЕ .nol suite (тот ждёт evaluator).
cd "$(dirname "$0")/.."
rm -f /tmp/nol-agent.seed
fail=0
check() {  # $1 файл теста, $2.. ожидаемые маркеры
  local f="$1"; shift
  local out; out=$(sbcl --script "test/$f" 2>&1)
  local ok=1
  for m in "$@"; do grep -qF "$m" <<<"$out" || { ok=0; echo "  ✗ $f: нет маркера «$m»"; }; done
  if [ $ok = 1 ]; then echo "  ✓ $f"; else fail=1; fi
}
echo "nolang smoke-тесты (восемь камней):"
check 00_atom.lisp   "value=T"          "отвергнут"        "Атом собирается только"
check 01_gate.lisp   "CONFIDENT-YES"    "FOLD-FIRST"       "DENIED"
check 02_return.lisp "SPROUTED-REMEMBERING" "ALREADY-CROSSED" "APPLIED"
check 03_eval.lisp   "APPLY"            "ROUTE"           "FOLD-FIRST"
check 04_nol.lisp    "migration.nol"    "исполнил сам себя" "ROUTE"
check 05_world.lisp  "ROLLED-BACK-WORLD-AND-SELF" "BLOCKED-IRREVERSIBLE" "== после ? T"
check 06_types.lisp  ":DONE"            ":ROUTE"          ":UNMET"
check 07_nars.lisp   "nars:вывод"       "SOCRATES"        "0.810"
echo
[ $fail = 0 ] && echo "ВСЁ ЗЕЛЁНО ✓" || { echo "ЕСТЬ ПАДЕНИЯ ✗"; exit 1; }
