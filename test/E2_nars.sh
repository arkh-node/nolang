#!/bin/bash
# E2/Ш2.3 — обратная связь NARS→(f,c) сдвигает вердикт gate. Нужен ONA NAR (иначе SKIP).
cd "$(dirname "$0")/.."
if [ -z "$NAR" ] && command -v NAR >/dev/null 2>&1; then NAR=$(command -v NAR); fi
export NAR
if [ -z "$NAR" ] || [ ! -x "$NAR" ]; then
  echo "  · E2_nars SKIP: нет ONA NAR (export NAR=/path/to/ONA/NAR) — мост опционален"; exit 0
fi
ok=0; fail=0
out=$(sbcl --script test/nars/_feedback.lisp 2>&1)
while read -r line; do
  case "$line" in
    OK*)   echo "  ✓ ${line#OK }"; ok=$((ok+1));;
    FAIL*) echo "  ✗ ${line#FAIL }"; fail=1;;
  esac
done <<< "$out"
echo "$out" | grep -E "без NARS:|с NARS:" | sed 's/^/  /'
echo "ИТОГ: $ok"
exit $fail
