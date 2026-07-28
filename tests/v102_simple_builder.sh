#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/*.sh; do . "$f"; done

grep -q '^new|Create a New RootFS|v103_build_new|' "$BASE/menus/build.menu"
grep -q '^current|Current Build|v103_build_review|' "$BASE/menus/build.menu"
grep -q '^advanced|More Build Options|@menu:build_advanced|' "$BASE/menus/build.menu"
[ "$(grep -c '^[^#].*|' "$BASE/menus/build.menu")" -ge 4 ]
for fn in v102_guided_build v102_current_build_menu v102_advanced_build_menu v102_build_summary; do
  command -v "$fn" >/dev/null 2>&1
done
v91_menu_validate
printf 'v10.2+ simplified builder compatibility: PASS\n'
