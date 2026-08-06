#!/bin/bash
# R1_robustness — что гарантия порога даёт и чего НЕ даёт (этап E, 06.08.2026).
#
# 🔴 Этот сторож проверяет не работоспособность, а ГРАНИЦУ: что при нарушении
# обмениваемости гарантия рушится, а не деградирует плавно. Тест, подтверждающий
# только хорошее, оставил бы читателя с ложным чувством защищённости.
cd "$(dirname "$0")/.."
ok=0; fail=0
out=$(sbcl --script test/robust/_shift.lisp 2>&1; sbcl --script test/robust/_weighted.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   echo "  ✓ ${line#OK }"; ok=$((ok+1));;
    FAIL*) echo "  ✗ ${line#FAIL }"; fail=1;;
  esac
done <<< "$out"
echo "ИТОГ: $ok"
exit $fail
