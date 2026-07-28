#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$ROOT HOME=${TMPDIR:-/tmp}/ish-aok-v952-home.$$ XDG_STATE_HOME=$HOME/state TMPDIR=${TMPDIR:-/tmp}
mkdir -p "$HOME"
. "$ROOT/lib/core.sh"
for f in "$ROOT"/lib/*.sh; do [ "$f" = "$ROOT/lib/core.sh" ] || . "$f"; done
for f in "$ROOT"/modules/package/*.sh "$ROOT"/modules/services/*.sh "$ROOT"/modules/*.sh; do [ -r "$f" ] && . "$f"; done
command_registry_build
v952_menu_audit
[ -s "$V952_MENU_AUDIT_REPORT" ]
grep -q 'Result: PASS' "$V952_MENU_AUDIT_REPORT"
# Text menu must reject an out-of-range selection and never reuse a stale tag.
UI=text
TMP_DIR=$HOME/tmp; mkdir -p "$TMP_DIR"
printf '2\n' | ui_menu T P one One two Two >/dev/null
set +e
printf '2\n' | ui_menu T P only Only >/dev/null
rc=$?
set -e
[ "$rc" -eq "$UI_MENU_BACK_RC" ]
# Plain checklist defaults and explicit selection.
out=$(printf '\n' | ui_checklist T P alpha Alpha on beta Beta off)
[ "$out" = alpha ]
out=$(printf '2\n' | ui_checklist T P alpha Alpha on beta Beta off)
[ "$out" = beta ]
rm -rf "$HOME"
