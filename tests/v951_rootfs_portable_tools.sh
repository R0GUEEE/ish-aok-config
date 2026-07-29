#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v951-tools.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/rootfs/etc" "$TMP/rootfs/bin" "$TMP/out" "$TMP/ui"
printf '#!/bin/sh\n' >"$TMP/rootfs/bin/sh"
chmod +x "$TMP/rootfs/bin/sh"
printf 'ID=test\n' >"$TMP/rootfs/etc/os-release"

# Static integration checks.
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
[ -e "$BASE/menus/rootfs.menu" ]
[ ! -e "$BASE/menus/rootfs_transfer.menu" ]
! grep -Rqs 'v951_package_rootfs_directory' "$BASE/menus/build"*.menu
! grep -q 'chroot_anywhere' "$BASE/lib/dispatcher_v73.sh"
! grep -q 'package_rootfs' "$BASE/lib/dispatcher_v73.sh"
grep -q 'return "$UI_MENU_BACK_RC"' "$BASE/lib/ui.sh"

# Load enough runtime to validate helpers.
HOME=$TMP/home XDG_STATE_HOME=$TMP/state TMPDIR=$TMP/tmp
mkdir -p "$HOME" "$XDG_STATE_HOME" "$TMPDIR"
ISH_AOK_CONFIG_ROOT=$BASE
export HOME XDG_STATE_HOME TMPDIR ISH_AOK_CONFIG_ROOT
. "$BASE/lib/core.sh"
. "$BASE/lib/detect.sh"
. "$BASE/lib/aok_common.sh"
. "$BASE/lib/ui.sh"
. "$BASE/lib/rootfs_registry.sh"
. "$BASE/modules/zz_v944_rootfs_anywhere.sh"
. "$BASE/modules/zz_v951_rootfs_portable_tools.sh"

[ "$(v951_path_canonical "$TMP/rootfs")" = "$TMP/rootfs" ]
rootfs_anywhere_looks_valid "$TMP/rootfs"
[ "$(v951_safe_archive_name 'test root/fs')" = 'test-root-fs' ]

# Simulate whiptail cancellation: it must return the dedicated Back status.
UI=whiptail
whiptail(){ return 1; }
set +e
ui_menu Test Prompt one One >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ]

# Declarative Build Back must be consumed by the current menu, not propagated.
V91_MENU_DIR=$TMP/ui
cat >"$V91_MENU_DIR/build.menu" <<MENU
back|Back|@return|
MENU
. "$BASE/lib/menu_v91.sh"
UI=text
printf '1\n' | v91_menu_run build >/dev/null 2>&1

printf 'v9.5.1 portable RootFS tools tests passed\n'
