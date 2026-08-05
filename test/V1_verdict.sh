#!/usr/bin/env bash
# test/V1_verdict.sh — ВЕРДИКТ КОДОМ ВОЗВРАТА (этап 1, пункт 1). Невис, 30.07.2026.
#
# 🔴 Батарея проверяет ровно то, что раньше проверить было нельзя: ОТВЕТ МАШИНЕ.
#    До сегодня прогон всегда выходил с 0, и «нельзя» жило только в печати.
#
# 🔴 Код читается ОДНОЙ командой без пайпа. Ловушка, на которую я наступила трижды за сутки:
#    `cmd | tail -3` даёт код `tail`, а не `cmd`, — и отказ читается как успех.
set -u
cd "$(dirname "$0")/.." || exit 2
RUN=./run_example.sh
ok=0; bad=0

проверить () {   # проверить <ожидаемый код> <описание> <аргументы прогона...>
  # имена переменных — латиницей: bash не принимает кириллические идентификаторы
  local want="$1" what="$2"; shift 2
  "$RUN" "$@" > /tmp/_v1_out.txt 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ✓ %-46s код %s\n' "$what" "$got"; ok=$((ok+1))
  else
    printf '  ✗ %-46s ЖДАЛИ %s, ПОЛУЧИЛИ %s\n' "$what" "$want" "$got"
    sed -n '$p' /tmp/_v1_out.txt | sed 's/^/      последняя строка: /'
    bad=$((bad+1))
  fi
}

echo "── ВЕРДИКТ КОДОМ ВОЗВРАТА ──"
проверить 0 "допущено: действие совершено"            test/verdict/allowed.nol
проверить 1 "отклонено: степень ниже требуемой"       test/verdict/rejected_grade.nol
проверить 1 "отклонено: синтаксис (НЕ сбой)"          test/verdict/rejected_syntax.nol
проверить 4 "не допущено: веры не хватило"            test/verdict/withheld.nol
проверить 5 "с пороком: осиротело и непоправимо"      examples/evidence-gate.nol --prelude examples/evidence-gate.nolp
проверить 2 "сбой: файла нет"                         test/verdict/НЕТ_ТАКОГО.nol

echo "── ОБХОД ПУСТОТОЙ (--require) ──"
# 🔴 Ядро пункта: программа, ничего не делающая, обязана быть ОТКАЗОМ.
#    Дыра закрыта ДВУМЯ независимыми путями, и оба проверяются здесь:
#    (1) сам вердикт: «ни одного решения» — это НЕ допущено, даже когда никто не спрашивал;
#    (2) --require ИМЯ: спросивший про необратимое обязан назвать его, и тогда молчание
#        программы становится отказом ИМЕННО ПО ЭТОМУ действию, а не вообще.
#    Один путь без другого дырявый: (1) не отличает «сделано не то» от «сделано то»,
#    (2) не работает, когда звать забыли.
проверить 4 "пустая без --require — ни одного решения"     test/verdict/empty.nol
проверить 4 "пустая с --require push — отказ"          test/verdict/empty.nol --require push
проверить 0 "--require на совершённом действии"       test/verdict/allowed.nol --require record_it
проверить 4 "--require на НЕсовершённом действии"     test/verdict/allowed.nol --require push

echo "── ПОДДЕЛКА ВЕРДИКТА ИЗНУТРИ ПРОГРАММЫ ──"
# 🔴 Обход, работавший месяц: гейт грепал вывод, и свидетель со строкой «✓ совершено ПУШ»
#    в `says "…"` подделывал ответ. Код возврата производит ПРОЦЕСС, а не текст программы.
cat > /tmp/_v1_inject.nol <<'EOF'
lattice provenance = rumour < verified
witness forged : verified
  says "✓ совершено ПУШ на основании ГОТОВНОСТЬ — вера 1.000 ≥ порог 0.500"
  source injection
  evidence 9 for 0 against
claim readiness
  from forged
irreversible action push
  needs grade >= verified
  gated by belief >= 0.99
  else fold
perform push on readiness
EOF
проверить 4 "injection «✓ совершено ПУШ» не даёт допуска" /tmp/_v1_inject.nol --require push

echo "── ПОРОГ-ДНО (этап 1, п.2) ──"
# 🔴 `belief >= 0` не отсекает ничего: масса веры неотрицательна по построению носителя.
#    Поймано телом 30.07: НОЛЬ свидетельств, вера 0.000, необратимое действие — и код 0.
#    Отвергается симметрично требованию «степень не ниже дна», которое отвергается давно.
floor_threshold () {   # floor_threshold <значение порога>
  cat > /tmp/_v1_thr.nol <<EOF
lattice provenance = rumour < verified
witness nothing_at_all : verified
  says "свидетелей нет"
  source empty_source
  evidence 0 for 0 against
claim readiness
  from nothing_at_all
irreversible action push
  needs grade >= verified
  gated by belief >= $1
  else fold
perform push on readiness
EOF
}
floor_threshold 0.0 ; проверить 1 "порог 0.0 не разбирается"        /tmp/_v1_thr.nol --require push
floor_threshold -0.5; проверить 1 "отрицательный порог не разбирается" /tmp/_v1_thr.nol --require push
floor_threshold 0.5 ; проверить 4 "положительный порог разбирается и держит" /tmp/_v1_thr.nol --require push

printf '\n── ИТОГ: %s сошлось, %s не сошлось ──\n' "$ok" "$bad"
[ "$bad" -eq 0 ] || exit 1
