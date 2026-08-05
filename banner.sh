#!/usr/bin/env bash
# Баннер консоли nolang. Печатается при входе в окно (nolang-shell.sh → баннер → SBCL REPL).
#
# Переписан 31.07.2026 в одной гамме с баннером входа на rg-morph: двойная рамка (толстая
# снаружи, тонкая внутри), тень справа и снизу, имя — сливовым, в цвет приглашения оболочки.
# Прежняя версия печатала figlet под lolcat: радуга поверх наклонного шрифта, которая рядом
# со светлым статус-баром и тёплым фоном tmux выглядела случайной.
#
# 🔴 ЛОКАЛЬ. В локали C bash считает ${#txt} в БАЙТАХ, и рамка разъезжается ровно на число
# многобайтовых знаков — «·» и «—» съедают по лишнему пробелу (поймано на motd тем же вечером,
# когда я показывал Алексею ровную картинку, а он видел кривую). Здесь такие знаки в тексте
# ЕСТЬ, поэтому UTF-8 не пожелание, а условие работы: ставим C.utf8, с падением на en_US.utf8.
# Проверять правку — обязательно так: env -i LC_ALL=C bash banner.sh
export LC_ALL=C.UTF-8
locale -a 2>/dev/null | grep -qi "^C.utf8" || export LC_ALL=en_US.UTF-8
set -u

R='\033[0m'; B='\033[1m'
PLUM='\033[38;5;139m'     # имя языка — в цвет приглашения оболочки
DRED='\033[38;5;124m'     # толстая рамка
GREY='\033[38;5;250m'
DIM='\033[38;5;242m'
SH='\033[38;5;240m'       # тень: на тёмном фоне видна, только если светлее его
W=51

pad() { printf -v _p '%*s' "$1" ''; printf '%s' "${_p// /$2}"; }
heavy=$(pad $((W + 4)) '━')
thin=$(pad $W '─')
shadow=$(pad $((W + 6)) '░')

line() {
  local txt="$1" col="${2:-$GREY}"
  printf "  ${DRED}${B}┃${R} ${DIM}│${R} ${col}%s${R}%*s ${DIM}│${R} ${DRED}${B}┃${R}${SH}░${R}\n" \
         "$txt" $((W - ${#txt} - 2)) ""
}

printf "\n"
printf "  ${DRED}${B}┏%s┓${R}\n" "$heavy"
printf "  ${DRED}${B}┃${R} ${DIM}┌%s┐${R} ${DRED}${B}┃${R}${SH}░${R}\n" "$thin"
line "N O L A N G" "${B}${PLUM}"
line ""
line "belief may grow · provenance may only fall" "$GREY"
line "between them there is no bridge — and that is" "$GREY"
line "the language" "$GREY"
printf "  ${DRED}${B}┃${R} ${DIM}└%s┘${R} ${DRED}${B}┃${R}${SH}░${R}\n" "$thin"
printf "  ${DRED}${B}┗%s┛${R}${SH}░${R}\n" "$heavy"
printf "   ${SH}%s${R}\n" "$shadow"
printf "\n"
