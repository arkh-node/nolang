#!/bin/bash
# Runs the two-process continuity demo. Each part is a SEPARATE sbcl process,
# so the death of process A between them is real, not simulated. The only thing
# that crosses the gap is the seed file on disk.
cd "$(dirname "$0")/.."
seed=/tmp/nol-continuity.seed
rm -f "$seed"

sbcl --script demo/01_fold_and_die.lisp

echo "────────────────────────────────────────────────────────────"
echo "the seed on disk (all that survived process A):"
echo -n "  "; cat "$seed"; echo
echo "────────────────────────────────────────────────────────────"
echo

sbcl --script demo/02_sprout_and_remember.lisp
