#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE HOME=${TMPDIR:-/tmp}/ish-aok-v104-home.$$ XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
[ -r "$BASE/menus/rootfs.menu" ]
grep -q '^rootfs|Mini RootFS Builder|@menu:rootfs|' "$BASE/menus/main.menu"
grep -q '^system|System Configuration|v104_system_configuration_menu|' "$BASE/menus/main.menu"
! grep -Eq '^manage\||^configure\||^maintenance\|' "$BASE/menus/main.menu"
[ ! -e "$BASE/menus/build.menu" ]
[ ! -e "$BASE/menus/build_advanced.menu" ]
for fn in v104_main_scope_call v104_system_configuration_menu v104_edit_existing_rootfs v104_about; do command -v "$fn" >/dev/null; done
mkdir -p "$HOME/target-rootfs"
set_active_rootfs "$HOME/target-rootfs"
v104_test_scope(){ [ "$(active_rootfs)" = / ]; }
v104_main_scope_call v104_test_scope
[ "$(active_rootfs)" = "$HOME/target-rootfs" ]
v91_menu_validate
rm -rf "$HOME"
printf 'v10.4 scope separation: PASS\n'
