#!/usr/bin/env bash
# test/V4_permission.sh — ПРАВО: ТРЕБОВАНИЕ ≠ ПРЕДЪЯВЛЕНИЕ (этап 2). Невис, 30.07.2026.
#
# 🔴 Что здесь проверяется. До 30.07 выдача права жила ВНУТРИ объявления действия, а отзыв —
#    в программе: право можно было отозвать замером, но предъявить только линейкой. Теперь
#    обе стороны в программе (`permit` даёт, `revoke` отзывает), а в объявлении остаётся
#    требование «кто вправе» — и цель, без которой разрешение не имеет объекта.
# 🔴 Имена переменных латиницей (ЗАКОН Г10); код возврата — отдельной строкой (ЗАКОН Г8).
set -u
cd "$(dirname "$0")/.." || exit 2
PRE=examples/push.nolp
ok=0; bad=0
tmp=$(mktemp -d /tmp/_v4.XXXXXX)

BASE='witness battery : machine_check
  says "прогон батареи: всё зелёное"
  source battery_run
  evidence 9 for 0 against

claim readiness
  from battery
'

check () {   # check <код> <описание> <файл программы> [файл прелюдии]
  local want="$1" what="$2" prog="$3" pre="${4:-$PRE}"
  ./run_example.sh "$prog" --prelude "$pre" --require push > "$tmp/out.txt" 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ✓ %-50s код %s\n' "$what" "$got"; ok=$((ok+1))
  else
    printf '  ✗ %-50s ЖДАЛИ %s, ПОЛУЧИЛИ %s\n' "$what" "$want" "$got"
    sed -n '$p' "$tmp/out.txt" | sed 's/^/      /'
    bad=$((bad+1))
  fi
}

echo "── ПРАВО ПРЕДЪЯВЛЯЕТСЯ В ПРОГРАММЕ ──"
printf '%s\npermit push "продолжай этап 1" from alexey at "2026-07-30 стр.44 sha:1326238bfc98"\n\nperform push on readiness\n' "$BASE" > "$tmp/ok.nol"
check 0 "предъявлено по адресу — допущено" "$tmp/ok.nol"

printf '%s\nperform push on readiness\n' "$BASE" > "$tmp/none.nol"
check 1 "без предъявления — отклонено (не «мало веры»)" "$tmp/none.nol"

printf '%s\npermit push "я разрешаю" from emma at "поток"\n\nperform push on readiness\n' "$BASE" > "$tmp/foreign.nol"
check 1 "разрешение от того, кто не вправе — отклонено" "$tmp/foreign.nol"

# 🔴 Право, данное ПОСЛЕ действия, — не разрешение, а амнистия: оно оправдывает уже
#    совершённое. Разница та же, что между «можно» и «ну ладно, раз уж сделал».
printf '%s\nperform push on readiness\n\npermit push "задним числом" from alexey at "поток"\n' "$BASE" > "$tmp/backdated.nol"
check 1 "право задним числом — отклонено" "$tmp/backdated.nol"

echo "── ЦЕЛЬ: ПРАВО БЕЗ ОБЪЕКТА НЕ ЕСТЬ ПРАВО ──"
sed 's|  to "github.com/arkh-node/nolang"||' "$PRE" > "$tmp/no_target.nolp"
check 1 "outward без цели не разбирается" "$tmp/ok.nol" "$tmp/no_target.nolp"

echo "── ПОРЯДОК НЕОБЯЗАТЕЛЬНЫХ ЧАСТЕЙ СВОБОДЕН ──"
# части различимы по ключевому слову; требовать их порядка — заставлять помнить лишнее
cat > "$tmp/reordered.nolp" <<'EOF'
lattice basis = hearsay < record < machine_check < outside_check

irreversible outward action push
  needs permission from alexey
  gated by belief >= 0.5
  else fold
  to "github.com/arkh-node/nolang"
  needs grade >= machine_check
EOF
check 0 "части в другом порядке читаются так же" "$tmp/ok.nol" "$tmp/reordered.nolp"

echo "── ЧЕТВЁРТЫЙ СТАТУС ЖИВ ПОСЛЕ ПЕРЕНОСА ──"
# basis ЦЕЛО, вера не менялась — рухнуло ПРАВО. Это не осиротение.
printf '%s\npermit push "разрешаю" from alexey at "поток стр.1"\n\nperform push on readiness\n\nrevoke permission from alexey because "передумал"\n' "$BASE" > "$tmp/revoked.nol"
check 5 "отзыв после действия → неправомерно (код 5)" "$tmp/revoked.nol"
if grep -q "цитата, на которую ссылались" "$tmp/out.txt"; then
  printf '  ✓ %-50s цитата предъявлена\n' "…и вердикт показывает, на что ссылались"; ok=$((ok+1))
else
  printf '  ✗ %-50s цитаты НЕТ\n' "…и вердикт показывает, на что ссылались"; bad=$((bad+1))
fi

rm -rf "$tmp"
printf '\n── ИТОГ: %s сошлось, %s не сошлось ──\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
