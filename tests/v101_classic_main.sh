#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE HOME=${TMPDIR:-/tmp}/ish-aok-v101-home.$$ XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done
case "$VERSION" in 10.*|11.*) :;; *) exit 1;; esac
[ -r "$BASE/menus/main.menu" ]
[ ! -e "$BASE/menus/workspace.menu" ]
[ -r "$BASE/menus/rootfs.menu" ]
grep -q '^rootfs|Mini RootFS Builder|@menu:rootfs|' "$BASE/menus/main.menu"
[ ! -e "$BASE/menus/build.menu" ]
grep -q '^system|System Configuration|v104_system_configuration_menu|' "$BASE/menus/main.menu"
grep -q '^exit|Exit|@return|' "$BASE/menus/main.menu"
! grep -Rqs '^tasks|Task Center\|Workspace Context\|Workspace Overview' "$BASE/menus"
command_registry_build
! grep -Eq '^(build|queue|recipes|build_execution|build_profiles|rootfs_locations|unified_build)[[:space:]]' "$V73_ACTIONS_FILE"
! grep -q '^dashboard' "$V73_ACTIONS_FILE"
! grep -q '^workspace_context' "$V73_ACTIONS_FILE"
grep -q '^rootfs_builder' "$V73_ACTIONS_FILE"
v962_route_audit
grep -q '^Result: PASS$' "$V962_ROUTE_REPORT"
rm -rf "$HOME"
