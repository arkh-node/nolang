#!/bin/bash
# B1_source_ceiling — потолок степени по источнику. Заведён 05.08.2026 вместе с самой проверкой.
#
# 🔴 ЗАКОН: не существует программы, повышающей степень через источник.
# До 05.08 `witness x : machine_verified source my_imagination` типизировалось: источник был
# лишь ключом дедупликации. Здесь проверяется, что теперь — нет; и что честное объявление
# по-прежнему проходит (иначе «починка» свелась бы к запрету всего).
cd "$(dirname "$0")/.."
ok=0; fail=0
run() { sbcl --script test/sources/_run.lisp "$1" 2>&1; }

out=$(run test/sources/ceiling_inflated.nol)
if grep -q "не поднимается происхождением" <<<"$out"; then
  echo "  ✓ завышенная степень отвергнута"; ok=$((ok+1))
else
  echo "  ✗ завышенная степень ПРОШЛА — потолок по источнику не работает"; fail=1
fi

out=$(run test/sources/ceiling_honest.nol)
if grep -q "ТИПИЗИРУЕТСЯ" <<<"$out"; then
  echo "  ✓ честная степень принята"; ok=$((ok+1))
else
  echo "  ✗ честная степень отвергнута — потолок режет лишнее"; echo "$out" | head -3; fail=1
fi

# B5: отпечаток и происхождение доживают до вывода наружу
out=$(sbcl --script test/sources/_provn.lisp 2>&1)
for m in 'nolang:class="randomised·full_report"' 'nolang:fingerprint="doi:' 'wasDerivedFrom(nolang:abstracts, nolang:ten_trials)'; do
  if grep -qF "$m" <<<"$out"; then
    echo "  ✓ в PROV-N дошло: ${m:0:44}"; ok=$((ok+1))
  else
    echo "  ✗ в PROV-N НЕ дошло: $m"; fail=1
  fi
done

echo "ИТОГ: $ok"
exit $fail
