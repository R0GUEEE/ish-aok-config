#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v94.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
HOME=$TMP/home; XDG_STATE_HOME=$TMP/state; mkdir -p "$HOME" "$XDG_STATE_HOME"
export ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; . "$f"; done
for f in "$BASE"/modules/*.sh; do . "$f"; done
case "$VERSION" in 9.[4-9].*|10.*|11.*) :;; *) exit 1;; esac
v94_install_templates
v94_install_package_groups
[ -f "$V94_TEMPLATE_DIR/development.profile" ]
[ "$(v94_group_resolve development alpine)" = 'build-base git curl wget pkgconf' ]
child=$TMP/child.profile; printf 'EXTENDS=development\nDISTRO=alpine\nPACKAGES=extra\n' >"$child"
resolved=$TMP/resolved.profile; v94_profile_resolve "$child" "$resolved"
grep -q '^CREATE_ARCHIVE=yes$' "$resolved"
grep -q '^DISTRO=alpine$' "$resolved"
m=$(v94_matrix_create smoke); v94_matrix_add "$m" "$child" alpine edge arm64
v94_matrix_validate "$m" >/dev/null
v94_matrix_plan "$m" | grep -q 'alpine'
v94_capability_report | grep -q 'debootstrap'
grep -q '^matrix|' "$BASE/menus/build_advanced.menu"
grep -q -- '--build-matrix-report' "$BASE/modules/main.sh"
