#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)
case "$BASE" in */tests) BASE=$(CDPATH= cd -- "$BASE/.." && pwd);; esac
export ISH_AOK_CONFIG_ROOT=$BASE HOME=${TMPDIR:-/tmp}/ish-aok-compat-home.$$ XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for x in "$BASE"/lib/*.sh; do [ "$x" = "$BASE/lib/core.sh" ] || . "$x"; done
for x in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$x" ] && . "$x"; done
[ -r "$BASE/menus/main.menu" ]
[ ! -e "$BASE/menus/workspace.menu" ]
command -v workspace_dashboard_v90 >/dev/null
ui_menu(){ return "${UI_MENU_BACK_RC:-90}"; }
workspace_dashboard_v90
rm -rf "$HOME"
