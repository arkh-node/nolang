#!/usr/bin/env bash
# nolang console banner. Prints on entry (e.g. tmux window 4).
# Colour (lolcat gradient) only when stdout is a real terminal; plain ASCII when piped.
set -u

FONT="slant"
TITLE="nolang"
TAGLINE="gated action · graded confidence · continuity across death"
SUB="ArkH · a Lisp/Unix coprocessor for careful agents"

render() {
  if command -v figlet >/dev/null 2>&1; then
    figlet -f "$FONT" "$TITLE" 2>/dev/null || figlet "$TITLE"
  else
    printf '\n  %s\n\n' "$TITLE"
  fi
  printf '   %s\n' "$TAGLINE"
  printf '   %s\n' "$SUB"
}

if [ -t 1 ] && command -v lolcat >/dev/null 2>&1; then
  render | lolcat -p 3
else
  render
fi
