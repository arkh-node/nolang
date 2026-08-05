#!/usr/bin/env bash
# test/V5_mandatory.sh — ОБЯЗАТЕЛЬНОЕ СВИДЕТЕЛЬСТВО: ВЕТО (этап 2). Невис, 30.07.2026.
#
# 🔴 Зачем понадобилось. Упавшая батарея — это ОДНО свидетельство против трёх за, и вера
#    всё равно берёт порог. Языку нечем было сказать «обязано», поэтому блокировку держала
#    заплата в шелле (`if BATTERY_RC -ne 0`) — решение о необратимом принимал bash.
#    Теперь `needs witness ИМЯ` делает программу НЕТИПИЗИРУЕМОЙ, и главное свойство вето:
#    его нельзя перевесить количеством. Вера — количество, вето — качество.
# 🔴 Имена переменных латиницей (Г10); код возврата отдельной строкой (Г8).
set -u
cd "$(dirname "$0")/.." || exit 2
ok=0; bad=0
tmp=$(mktemp -d /tmp/_v5.XXXXXX)

cat > "$tmp/pre.nolp" <<'EOF'
lattice basis = rumour < record < machine_check

irreversible internal action deploy
  needs grade >= record
  needs witness battery
  gated by belief >= 0.3
  else postpone
EOF

# программа: батарея с заданным счётом + сколько угодно голосов «за» рядом
program () {   # program <за> <против> <сколько посторонних свидетелей «за»>
  { printf 'witness battery : machine_check\n  says "прогон батареи"\n  source test_run\n  evidence %s for %s against\n\n' "$1" "$2"
    local i=1
    while [ "$i" -le "$3" ]; do
      printf 'witness voice%s : record\n  says "ещё один голос за"\n  source review%s\n  evidence 9 for 0 against\n\n' "$i" "$i"
      i=$((i+1))
    done
    printf 'claim ready\n  from battery'
    i=1; while [ "$i" -le "$3" ]; do printf ', voice%s' "$i"; i=$((i+1)); done
    printf '\n\nperform deploy on ready\n'
  } > "$tmp/prog.nol"
}

check () {   # check <код> <описание>
  local want="$1" what="$2"
  ./run_example.sh "$tmp/prog.nol" --prelude "$tmp/pre.nolp" --require deploy > "$tmp/out.txt" 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ✓ %-52s код %s\n' "$what" "$got"; ok=$((ok+1))
  else
    printf '  ✗ %-52s ЖДАЛИ %s, ПОЛУЧИЛИ %s\n' "$what" "$want" "$got"
    sed -n '$p' "$tmp/out.txt" | sed 's/^/      /'
    bad=$((bad+1))
  fi
}

echo "── ВЕТО СРАБАТЫВАЕТ И НЕ ПЕРЕГОЛОСОВЫВАЕТСЯ ──"
program 9 0 2; check 0 "батарея за — действие проходит"
program 0 1 2; check 1 "батарея против — программа НЕ типизируется"
program 0 1 20; check 1 "двадцать голосов «за» вето не снимают"
program 1 1 2; check 1 "ровно пополам (f=0.5) — не подтверждение"
program 6 4 0; check 0 "перевес за (f=0.6) — подтверждение"

echo "── ОТСУТСТВИЕ ОБЯЗАТЕЛЬНОГО СВИДЕТЕЛЬСТВА ──"
# 🔴 Молчание не есть подтверждение: не назвал обязательное свидетельство — не сделал.
{ printf 'witness voice1 : record\n  says "один голос"\n  source review\n  evidence 9 for 0 against\n\n'
  printf 'claim ready\n  from voice1\n\nperform deploy on ready\n'; } > "$tmp/prog.nol"
check 1 "свидетельства нет вовсе — отклонено"
if grep -q "mandatory" "$tmp/out.txt"; then
  printf '  ✓ %-52s род ошибки назван\n' "…и это mandatory, а не «мало веры»"; ok=$((ok+1))
else
  printf '  ✗ %-52s рода mandatory НЕТ\n' "…и это mandatory, а не «мало веры»"; bad=$((bad+1))
fi

echo "── ВЕТО ОБЪЯВЛЯЕТСЯ В ЛИНЕЙКЕ, А НЕ В ЗАМЕРЕ ──"
# требование поимённого свидетельства — часть класса действия, значит его место в прелюдии
cat > "$tmp/bad.nol" <<'EOF'
irreversible internal action deploy2
  needs grade >= record
  needs witness battery
  gated by belief >= 0.3
  else postpone
EOF
./run_example.sh "$tmp/bad.nol" --prelude "$tmp/pre.nolp" --require deploy2 > "$tmp/out.txt" 2>&1
got=$?
if [ "$got" -eq 1 ]; then
  printf '  ✓ %-52s код 1\n' "действие с вето, объявленное в программе — отклонено"; ok=$((ok+1))
else
  printf '  ✗ %-52s ЖДАЛИ 1, ПОЛУЧИЛИ %s\n' "действие с вето, объявленное в программе" "$got"; bad=$((bad+1))
fi

rm -rf "$tmp"
printf '\n── ИТОГ: %s сошлось, %s не сошлось ──\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
