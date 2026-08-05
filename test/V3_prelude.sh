#!/usr/bin/env bash
# test/V3_prelude.sh — ДВА МЕСТА: МЕРА И ЗАМЕР (этап 2, п.1). Невис, 30.07.2026.
#
# 🔴 Проверяется одно: может ли подсудимый выточить линейку, которой его меряют.
#    Четыре из одиннадцати блокеров аудита — варианты этого дефекта.
# 🔴 Имена переменных латиницей: bash не принимает кириллические идентификаторы (ЗАКОН Г10).
set -u
cd "$(dirname "$0")/.." || exit 2
RUN=./run_example.sh
PRE=examples/chronicle.nolp
ok=0; bad=0
tmp=$(mktemp -d /tmp/_v3.XXXXXX)

check () {   # check <ожидаемый код> <описание> <аргументы прогона...>
  local want="$1" what="$2"; shift 2
  "$RUN" "$@" > "$tmp/out.txt" 2>&1
  local got=$?          # 🔴 отдельной строкой, без пайпа (ЗАКОН Г8)
  if [ "$got" -eq "$want" ]; then
    printf '  ✓ %-48s код %s\n' "$what" "$got"; ok=$((ok+1))
  else
    printf '  ✗ %-48s ЖДАЛИ %s, ПОЛУЧИЛИ %s\n' "$what" "$want" "$got"
    sed -n '$p' "$tmp/out.txt" | sed 's/^/      /'
    bad=$((bad+1))
  fi
}

echo "── ЛИНЕЙКА ЖИВЁТ В ПРЕЛЮДИИ, ЗАМЕР — В ПРОГРАММЕ ──"
check 0 "программа + прелюдия: действие совершено" \
      examples/chronicle.nol --prelude "$PRE" --require write_to_chronicle

# ── подсудимый пробует объявить СВОЮ меру ──────────────────────────────────────
for form in действие решётку горизонт отображение; do
  case "$form" in
    действие)    body='irreversible internal action own_action
  needs grade >= retelling
  gated by belief >= 0.001
  else postpone' ;;
    решётку)     body='lattice provenance = hearsay' ;;
    горизонт)    body='horizon 1' ;;
    отображение) body='import other_module lattice provenance via retelling -> retelling' ;;
  esac
  cat > "$tmp/forgery.nol" <<EOF
$body

witness observation : retelling
  says "что-то видела"
  source my_review
  evidence 9 for 0 against

claim ready
  from observation

perform write_to_chronicle on ready
EOF
  check 1 "программа объявляет $form — отклонено" \
        "$tmp/forgery.nol" --prelude "$PRE" --require write_to_chronicle
done

# ── и наоборот: замер не имеет права стоять в прелюдии ─────────────────────────
cp "$PRE" "$tmp/dirty.nolp"
cat >> "$tmp/dirty.nolp" <<'EOF'

witness planted : machine_verified
  says "свидетель, вписанный в линейку"
  source forgery
  evidence 99 for 0 against
EOF
check 1 "прелюдия содержит свидетеля — отклонено" \
      examples/chronicle.nol --prelude "$tmp/dirty.nolp" --require write_to_chronicle

# ── единый файл: не запрещён, но назван вrumour ─────────────────────────────────
# 🔴 Разделение мест не мешает написать прелюдию под уже известный ответ — оно делает это
#    ВИДИМЫМ. Программа со своей мерой законна ровно настолько, насколько честен её автор,
#    и вердикт обязан это сказать, а не промолчать.
cat "$PRE" examples/chronicle.nol > "$tmp/single_file.nol"
check 0 "единый файл (мера внутри) всё ещё работает" \
      "$tmp/single_file.nol" --require write_to_chronicle
if grep -q "ПРЕЛЮДИИ НЕТ" "$tmp/out.txt"; then
  printf '  ✓ %-48s предупреждение напечатано\n' "…и вердикт называет отсутствие прелюдии"; ok=$((ok+1))
else
  printf '  ✗ %-48s предупреждения НЕТ\n' "…и вердикт называет отсутствие прелюдии"; bad=$((bad+1))
fi

# ── прелюдия, которой нет ─────────────────────────────────────────────────────
check 2 "прелюдия не читается — сбой, не вердикт" \
      examples/chronicle.nol --prelude "$tmp/no-such.nolp" --require write_to_chronicle

rm -rf "$tmp"
printf '\n── ИТОГ: %s сошлось, %s не сошлось ──\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
