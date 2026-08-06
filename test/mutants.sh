#!/usr/bin/env bash
# mutants — МУТАЦИОННЫЙ СТЕНД ПО ВСЕЙ БАТАРЕЕ. Заведён ArkH 06.08.2026 (клетка A2).
#
# 🔴 ЗАЧЕМ. Чувствительность батареи была измерена РОВНО НА ОДНОЙ функции (`g-meet`, оракул).
# Про остальные несущие места — потолок источника, кредальную границу, гейт, журнал, отпечаток,
# силу якоря — не было известно НИЧЕГО: ловит ли их порчу хоть одна из 910 проверок. Батарея,
# чувствительность которой измерена на одной функции, о прочих не свидетельствует.
#
# 🔴 ЧТО ЗДЕСЬ ПРОВЕРЯЕТСЯ. Не «падает ли батарея» — этого мало. Проверяется, что порча
# **наблюдаема** (меняет поведение) И что её ловит хоть кто-то. Мутация, не меняющая поведения,
# — не дыра в батарее, а эквивалентная запись; таких в A1 нашлось 47 из 200, и путать эти два
# случая значит мерить разнообразие вместо зоркости.
#
# ⚠️ Agda НЕ прогоняется: порча лисп-функции на неё не влияет, а сборка с нуля стоит минут.
# Это сказано вслух, а не умолчано: стенд меряет лисп-часть батареи, и только её.
#
# Выход: для каждой мутации — ПОЙМАНА (и кем) либо 🔴 НЕ ПОЙМАНА (дыра).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

run_battery() {   # → 0 если батарея зелёная, 1 если хоть что-то упало; печатает кто упал
  local failed=""
  for t in test/*.lisp; do
    out=$(timeout 300 sbcl --script "$t" 2>&1); rc=$?
    if [ $rc -ne 0 ] || echo "$out" | grep -q "Unhandled\|FAIL:"; then
      failed="$failed $(basename "$t")"
    fi
  done
  for t in test/*.sh; do
    [ "$(basename "$t")" = "mutants.sh" ] && continue
    out=$(timeout 300 bash "$t" 2>&1); rc=$?
    [ $rc -ne 0 ] && failed="$failed $(basename "$t")"
  done
  echo "$failed"
}

mutate() {  # name · file · old · new
  local name="$1" file="$2" old="$3" new="$4"
  cp "$file" "$TMP/backup"
  python3 - "$file" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
if old not in s:
    sys.stderr.write("ЯКОРЬ НЕ НАЙДЕН\n"); sys.exit(2)
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  if [ $? -ne 0 ]; then
    printf '  %-38s ⚠️  якорь не найден — мутация НЕ ПРИМЕНЕНА (это не успех)\n' "$name"
    cp "$TMP/backup" "$file"; SKIPPED=$((SKIPPED+1)); return
  fi
  local failed; failed=$(run_battery)
  cp "$TMP/backup" "$file"
  if [ -n "$failed" ]; then
    # 🔴 СЧИТАЕТСЯ НЕ ТОЛЬКО «ПОЙМАНА», НО И СКОЛЬКИМИ. Место, которое ловит РОВНО ОДНА
    # проверка, — не дыра сегодня, но одиночная опора: сломайся она или окажись зелёной по
    # неверной причине (за одни сутки такое случилось дважды), и порча пройдёт молча.
    # Число ловцов есть ЗАПАС ПРОЧНОСТИ, и он должен быть виден, а не вычисляться читателем.
    local n; n=$(echo $failed | wc -w)
    if [ "$n" -eq 1 ]; then
      printf '  %-38s ⚠️  поймана ОДНОЙ проверкой (%s) — опора одна\n' "$name" "$failed"
      LONE=$((LONE+1))
    else
      printf '  %-38s ✓ поймана %2s проверками:%s\n' "$name" "$n" "$failed"
    fi
    CAUGHT=$((CAUGHT+1))
  else
    printf '  %-38s 🔴 НЕ ПОЙМАНА — ДЫРА В БАТАРЕЕ\n' "$name"
    HOLES=$((HOLES+1))
  fi
}

CAUGHT=0; HOLES=0; SKIPPED=0; LONE=0
echo "── МУТАЦИОННЫЙ СТЕНД: ловит ли батарея порчу несущих мест ──"

# ── решётка ───────────────────────────────────────────────────────────────────
mutate "g-meet → первый довод" src/common.lisp \
  '(defun g-meet (a b) (g-meet-in *lattice* a b))' \
  '(defun g-meet (a b) (declare (ignore b)) a)'

mutate "g<= → всегда истина" src/common.lisp \
  '(defun g<= (a b) (g<=-in *lattice* a b))' \
  '(defun g<= (a b) (declare (ignore a b)) t)'

# ── потолок происхождения ─────────────────────────────────────────────────────
mutate "source-class → класса нет" src/check.lisp \
  '  (let ((rec (cdr (assoc name *sources*))))' \
  '  (return-from source-class nil)
  (let ((rec (cdr (assoc name *sources*))))'

# ── журнал ────────────────────────────────────────────────────────────────────
mutate "журнал: ledger-of пропускает всё" src/verdict.lisp \
  '  (remove-if-not (lambda (e) (member (first e) kinds)) ledger))' \
  '  (declare (ignore kinds)) ledger)'

mutate "отзыв не помечает сироту" src/verdict.lisp \
  '(defun rejecting-errors (errs)' \
  '(defun rejecting-errors (errs) (return-from rejecting-errors nil)
   (progn'

# ── кредальная граница ────────────────────────────────────────────────────────
mutate "интервал схлопнут в точку" src/evidence.lisp \
  '(lo (/ w+ (+ w k)))
         (hi (/ (+ w+ k) (+ w k))))' \
  '(lo (/ w+ (+ w k)))
         (hi (/ w+ (+ w k))))'

# ── гейт ──────────────────────────────────────────────────────────────────────
mutate "гейт: outcome всегда пропускает" src/gate.lisp \
  '(defun outcome (a &optional (theta *theta*))' \
  '(defun outcome (a &optional (theta *theta*)) (return-from outcome :yes)
   (progn'

# ── отпечаток и якорь ─────────────────────────────────────────────────────────
mutate "отпечаток субъекта — константа" src/subject.lisp \
  '(digest-string (format nil "~s|~s|~s|~s"' \
  '(digest-string (format nil "КОНСТАНТА~*~*~*~*" '

mutate "сила якоря всегда :notarised" src/anchor.lisp \
  '(let* ((actual (or (cdr (assoc channel *channel-classes*)) :self))' \
  '(let* ((actual :notarised)'

echo "────────────────────────────────────────────────────────────"
echo "ПОЙМАНО: $CAUGHT · ДЫР: $HOLES · НЕ ПРИМЕНЕНО: $SKIPPED · ОДИНОЧНАЯ ОПОРА: $LONE"
[ "$LONE" -gt 0 ] && echo "⚠️ Места с одной опорой держатся на одной батарее — это запас прочности, а не дефект, но знать о нём обязательно."
[ "$SKIPPED" -gt 0 ] && echo "⚠️ Непринятая мутация — НЕ успех: место не проверено вовсе."
echo "ИТОГ: $CAUGHT"
[ "$HOLES" -eq 0 ] && [ "$SKIPPED" -eq 0 ]
