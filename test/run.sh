#!/bin/bash
# smoke-runner: runs the eight stone tests, checks key markers in their output.
cd "$(dirname "$0")/.."
rm -f /tmp/nol-agent.seed
fail=0
# Stone 07 (the NARS bridge) is optional: it needs ONA's NAR binary.
# Use $NAR if set, else NAR on PATH; otherwise stone 07 is skipped.
if [ -z "$NAR" ] && command -v NAR >/dev/null 2>&1; then NAR=$(command -v NAR); fi
export NAR
check() {  # $1 test file, $2.. expected markers
  local f="$1"; shift
  local out; out=$(sbcl --script "test/$f" 2>&1)
  # Пропуск из-за отсутствующей внешней зависимости — НЕ провал. Тот же приём, что у 07_nars
  # с бинарником ONA: отсутствие зависимости и поломка кода обязаны быть различимы.
  if grep -q "^SKIP " <<<"$out"; then
    echo "  · $f $(grep -m1 "^SKIP " <<<"$out" | sed "s/^SKIP [^:]*: //")"
    return 0
  fi
  local ok=1
  for m in "$@"; do grep -qF "$m" <<<"$out" || { ok=0; echo "  ✗ $f: missing marker «$m»"; }; done
  if [ $ok = 1 ]; then echo "  ✓ $f"; else fail=1; fi
}
echo "nolang smoke tests (eight stones):"
check 00_atom.lisp   "value=T"          "rejected"         "An atom is built only"
check 01_gate.lisp   "CONFIDENT-YES"    "FOLD-FIRST"       "DENIED"
check 02_return.lisp "SPROUTED-REMEMBERING" "ALREADY-CROSSED" "APPLIED"
check 03_eval.lisp   "APPLY"            "ROUTE"           "FOLD-FIRST"
check 04_nol.lisp    "migration.nol"    "ran itself"       "ROUTE"
check 05_world.lisp  "ROLLED-BACK-WORLD-AND-SELF" "BLOCKED-IRREVERSIBLE" "== after ? T"
check 06_types.lisp  ":DONE"            ":ROUTE"          ":UNMET"
if [ -n "$NAR" ] && [ -x "$NAR" ]; then
  check 07_nars.lisp "nars:output"      "SOCRATES"        "0.810"
else
  echo "  · 07_nars.lisp skipped (set NAR=/path/to/ONA/NAR to run the NARS bridge — optional)"
fi
echo
[ $fail = 0 ] && echo "ALL GREEN ✓" || { echo "FAILURES ✗"; exit 1; }
