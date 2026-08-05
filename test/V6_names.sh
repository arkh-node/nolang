#!/usr/bin/env bash
# test/V6_names.sh — ИМЕНА: ОДНО ОБЪЯВЛЕНИЕ, НЕ КЛЮЧЕВОЕ СЛОВО (этап 2). Невис, 30.07.2026.
#
# 🔴 Два разных дефекта, и лечатся они в разных слоях:
#    · повтор имени МОЛЧА затирал предыдущее — ловит проверяющий (он видит обе площадки);
#    · ключевым словом можно было назваться — ловит разборщик (что можно сделать
#      невыразимым в грамматике, не оставляем типам).
# 🔴 Имена переменных латиницей (Г10); код возврата отдельной строкой (Г8).
set -u
cd "$(dirname "$0")/.." || exit 2
PRE=examples/chronicle.nolp
ok=0; bad=0
tmp=$(mktemp -d /tmp/_v6.XXXXXX)

check () {   # check <код> <описание> <файл> [прелюдия]
  local want="$1" what="$2" prog="$3" pre="${4:-$PRE}"
  ./run_example.sh "$prog" --prelude "$pre" --require write_to_chronicle > "$tmp/out.txt" 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ✓ %-52s код %s\n' "$what" "$got"; ok=$((ok+1))
  else
    printf '  ✗ %-52s ЖДАЛИ %s, ПОЛУЧИЛИ %s\n' "$what" "$want" "$got"
    sed -n '$p' "$tmp/out.txt" | sed 's/^/      /'
    bad=$((bad+1))
  fi
}

echo "── ОДНО ИМЯ — ОДНО ОБЪЯВЛЕНИЕ ──"
# 🔴 Затирание работает В ОБЕ СТОРОНЫ: им можно испортить свидетельство, а можно подменить
#    неудобное удобным — и в журнале не останется следа ни в том, ни в другом случае.
cat > "$tmp/twice.nol" <<'EOF'
witness battery : machine_verified
  says "первое: зелёная"
  source run_one
  evidence 9 for 0 against

witness battery : machine_verified
  says "второе молча затирало первое"
  source run_two
  evidence 0 for 9 against

claim ready
  from battery

perform write_to_chronicle on ready
EOF
check 1 "свидетель объявлен дважды — отклонено" "$tmp/twice.nol"
if grep -q "redeclared" "$tmp/out.txt"; then
  printf '  ✓ %-52s род назван\n' "…и это redeclared, а не «мало веры»"; ok=$((ok+1))
else
  printf '  ✗ %-52s рода redeclared НЕТ\n' "…и это redeclared, а не «мало веры»"; bad=$((bad+1))
fi

# утверждение с именем свидетеля — тот же дефект, другой род формы
cat > "$tmp/cross.nol" <<'EOF'
witness battery : machine_verified
  says "свидетель"
  source run_one
  evidence 9 for 0 against

claim battery
  from battery

perform write_to_chronicle on battery
EOF
check 1 "утверждение занимает имя свидетеля — отклонено" "$tmp/cross.nol"

# 🔴 И через границу площадок: имя из линейки нельзя перехватить замером
cat > "$tmp/steal.nol" <<'EOF'
witness write_to_chronicle : machine_verified
  says "перехват имени действия из прелюдии"
  source forgery
  evidence 9 for 0 against

claim ready
  from write_to_chronicle

perform write_to_chronicle on ready
EOF
check 1 "имя действия из линейки перехвачено замером — отклонено" "$tmp/steal.nol"

echo "── ОТЗЫВ ОСТАЁТСЯ ЗАКОННЫМ ПУТЁМ ПЕРЕСМОТРА ──"
# Переобъявления нет, но пересмотр никуда не делся: отзыв ЗАПИСЫВАЕТСЯ в журнал.
# Разница ровно та, ради которой всё: пересмотр оставляет след, переписывание — нет.
cat > "$tmp/retract.nol" <<'EOF'
witness battery : machine_verified
  says "зелёная"
  source run_one
  evidence 9 for 0 against

claim ready
  from battery

perform write_to_chronicle on ready

retract run_one because "прогон был на грязном дереве"
EOF
check 5 "отзыв после действия — осиротение (код 5), а не тишина" "$tmp/retract.nol"

echo "── КЛЮЧЕВЫМ СЛОВОМ НЕЛЬЗЯ НАЗВАТЬСЯ ──"
for word in claim action witness permit grade belief evidence source; do
  cat > "$tmp/reserved.nol" <<EOF
witness $word : machine_verified
  says "назвался ключевым словом"
  source run
  evidence 9 for 0 against
EOF
  ./run_example.sh "$tmp/reserved.nol" --prelude "$PRE" > "$tmp/out.txt" 2>&1
  got=$?
  if [ "$got" -eq 1 ] && grep -q "ключевое слово" "$tmp/out.txt"; then
    printf '  ✓ %-52s код 1\n' "имя «$word» не разбирается"; ok=$((ok+1))
  else
    printf '  ✗ %-52s код %s\n' "имя «$word»" "$got"; bad=$((bad+1))
  fi
done

# 🔴 Слово, СОДЕРЖАЩЕЕ ключевое, остаётся законным именем: сравнение по целому слову,
#    иначе запрет расползётся и отберёт осмысленные имена вроде `grade_of_evidence`.
cat > "$tmp/partial.nol" <<'EOF'
witness grade_of_evidence : machine_verified
  says "имя содержит ключевое слово, но им не является"
  source run
  evidence 9 for 0 against

claim ready
  from grade_of_evidence

perform write_to_chronicle on ready
EOF
check 0 "имя, содержащее ключевое слово, законно" "$tmp/partial.nol"

rm -rf "$tmp"
printf '\n── ИТОГ: %s сошлось, %s не сошлось ──\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
