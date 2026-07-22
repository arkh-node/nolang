#!/usr/bin/env bash
# Raise nolang in a window: colour banner, then an interactive SBCL REPL with the core loaded.
cd /srv/langs/nolang || exit 1
clear
bash ./banner.sh
echo
sbcl --load repl.lisp
