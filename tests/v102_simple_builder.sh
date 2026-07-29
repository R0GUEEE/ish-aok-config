#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/*.sh; do . "$f"; done

[ ! -e "$BASE/menus/build.menu" ]
[ ! -e "$BASE/menus/build_advanced.menu" ]
[ -r "$BASE/menus/rootfs.menu" ]
grep -q '^guided|Configure and build|v1160_guided|' "$BASE/menus/rootfs.menu"
for fn in v102_guided_build v102_current_build_menu v102_advanced_build_menu v102_build_summary; do
  command -v "$fn" >/dev/null 2>&1
done
v91_menu_validate
printf 'v10.2+ simplified builder compatibility: PASS\n'
