#!/bin/bash
# C2_subject — возврат в субъекта (этап D). Восстановление есть воспроизведение.
cd "$(dirname "$0")/.."
ok=0; fail=0
out=$(sbcl --script test/subject/_check.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   echo "  ✓ ${line#OK }"; ok=$((ok+1));;
    FAIL*) echo "  ✗ ${line#FAIL }"; fail=1;;
  esac
done <<< "$out"
echo "ИТОГ: $ok"
exit $fail
