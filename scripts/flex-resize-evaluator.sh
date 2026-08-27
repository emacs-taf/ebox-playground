#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
emacs=${EMACS:-/Applications/Emacs.app/Contents/MacOS/Emacs}
emacsclient=${EMACSCLIENT:-/Applications/Emacs.app/Contents/MacOS/bin/emacsclient}
server="ebox-playground-flex-evaluator-$$"
fixture=$(mktemp "${TMPDIR:-/tmp}/ebox-flex-reference.XXXXXX")

require_fresh_elc() {
    source_file=$1
    elc_file=$2
    if [ ! -r "$elc_file" ] || [ "$source_file" -nt "$elc_file" ]; then
        echo "stale or missing evaluator artifact: $elc_file" >&2
        echo "run make performance-prepare first" >&2
        exit 1
    fi
}

cleanup() {
    "$emacsclient" -n -s "$server" -e '(kill-emacs 0)' >/dev/null 2>&1 || true
    rm -f "$fixture"
}
trap cleanup EXIT INT TERM

require_fresh_elc "$root/ebox-playground.el" "$root/ebox-playground.elc"
require_fresh_elc \
    "$root/scripts/ebox-playground-flex-resize-evaluator.el" \
    "$root/scripts/ebox-playground-flex-resize-evaluator.elc"
require_fresh_elc "$root/../ebox/ebox.el" "$root/../ebox/ebox.elc"
require_fresh_elc "$root/../ebox/ebox-surface.el" "$root/../ebox/ebox-surface.elc"
require_fresh_elc "$root/../ecss/ecss.el" "$root/../ecss/ecss.elc"
require_fresh_elc "$root/../tp/tp.el" "$root/../tp/tp.elc"

: "${EBOX_NATIVE_REFLOW_MODULE_PATH:?run make performance-prepare first}"
if [ ! -r "$EBOX_NATIVE_REFLOW_MODULE_PATH/libebox_native_reflow.dylib" ]; then
    echo "prepared Ebox native module is missing" >&2
    exit 1
fi

git -C "$root" show HEAD:examples/flex-reference.ebox >"$fixture"
export EBOX_PLAYGROUND_FLEX_FIXTURE=$fixture

# Keep the evaluator package-only, but reproduce only the four startup values
# that directly affect this render path.  Loading the complete user init would
# add unrelated packages, timers, and UI state to the performance gate.
"$emacs" -Q --daemon="$server" \
    -L "$root" -L "$root/../ebox" -L "$root/../ecss" \
    -L "$root/../tp" \
    --eval '(setq load-prefer-newer t
                  native-comp-jit-compilation nil
                  ebox-native-reflow-module-path
                  (getenv "EBOX_NATIVE_REFLOW_MODULE_PATH")
                  gc-cons-threshold most-positive-fixnum
                  gc-cons-percentage 0.6
                  file-name-handler-alist nil
                  auto-window-vscroll nil)' \
    -l "$root/ebox-playground" \
    -l "$root/scripts/ebox-playground-flex-resize-evaluator"

output=$("$emacsclient" -n -s "$server" -c -e \
    '(ebox-playground-flex-resize-evaluator-run)' 2>&1)
printf '%s\n' "$output"

if printf '%s\n' "$output" | grep -Fq 'FLEX-RESIZE-EVALUATOR PASS'; then
    exit 0
fi
exit 1
