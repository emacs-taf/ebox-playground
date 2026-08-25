#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
emacs=${EMACS:-/Applications/Emacs.app/Contents/MacOS/Emacs}
emacsclient=${EMACSCLIENT:-/Applications/Emacs.app/Contents/MacOS/bin/emacsclient}
server="ebox-playground-flex-evaluator-$$"

cleanup() {
    "$emacsclient" -n -s "$server" -e '(kill-emacs 0)' >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Keep the evaluator package-only, but reproduce only the four startup values
# that directly affect this render path.  Loading the complete user init would
# add unrelated packages, timers, and UI state to the performance gate.
"$emacs" -Q --daemon="$server" \
    -L "$root" -L "$root/../ebox" -L "$root/../ecss" \
    -L "$root/../tp" \
    --eval '(setq load-prefer-newer t
                  gc-cons-threshold most-positive-fixnum
                  gc-cons-percentage 0.6
                  file-name-handler-alist nil
                  auto-window-vscroll nil)' \
    -l "$root/ebox-playground.el" \
    -l "$root/scripts/ebox-playground-flex-resize-evaluator.el"

output=$("$emacsclient" -n -s "$server" -c -e \
    '(ebox-playground-flex-resize-evaluator-run)' 2>&1)
printf '%s\n' "$output"

if printf '%s\n' "$output" | grep -Fq 'FLEX-RESIZE-EVALUATOR PASS'; then
    exit 0
fi
exit 1
