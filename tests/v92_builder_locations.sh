#!/bin/sh
set -u
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)
TMP=${TMPDIR:-/tmp}/v92-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/home" "$TMP/state" "$TMP/parent"
HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" . "$BASE/lib/core.sh"
rootfs_registry_paths(){ :; }
. "$BASE/lib/rootfs_location_v92.sh"

p=$(rootfs_location_normalize '/AOK/roots/test///')
[ "$p" = '/AOK/roots/test' ]
rootfs_location_safe '/AOK/roots/test'
! rootfs_location_safe '/'
! rootfs_location_safe '/AOK'
! rootfs_location_validate 'relative/path' >/dev/null 2>&1
rootfs_location_validate "$TMP/parent/rootfs"
rootfs_location_remember "$TMP/parent/rootfs"
grep -F "$TMP/parent/rootfs" "$V92_RECENT_LOCATIONS" >/dev/null
[ "$(rootfs_location_default devuan excalibur arm64)" = '/AOK/roots/devuan-excalibur-arm64' ]
grep -q 'v93_paths_menu' "$BASE/menus/build_profile.menu"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'rootfs_location_select' "$BASE/modules/zz_v92_builder_locations.sh"
printf 'v9.2 builder locations: PASS\n'
