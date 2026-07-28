#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE
export HOME=${TMPDIR:-/tmp}/v91-menu-home.$$
export XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done
v91_menu_validate
[ "$(find "$BASE/menus" -name '*.menu' -type f | wc -l | tr -d ' ')" -ge 6 ]
rm -rf "$HOME"
