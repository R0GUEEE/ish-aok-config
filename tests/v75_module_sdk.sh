#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ish-aok-v75-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
HOME=$TMP/home
STATE_DIR=$TMP/state
mkdir -p "$HOME" "$STATE_DIR"
export HOME STATE_DIR ISH_AOK_CONFIG_ROOT=$BASE
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; . "$f"; done
active_rootfs(){ printf '%s\n' "$TMP/rootfs"; }
mkdir -p "$TMP/rootfs"
DISTRO_ID=devuan ARCH=aarch64 INIT_SYSTEM=sysvinit PKG_MGR=apt
export DISTRO_ID ARCH INIT_SYSTEM PKG_MGR
sdk_discover_modules
[ -s "$V75_MODULE_INDEX" ]
grep -q '^system_report' "$V75_MODULE_INDEX"
grep -q '^rootfs_quick' "$V75_MODULE_INDEX"
sdk_validate_manifest "$BASE/extensions/builtin/system_report/module.conf"
: >"$V73_ACTIONS_FILE.tmp"
sdk_register_actions
grep -q '^ext.system_report.inventory' "$V73_ACTIONS_FILE.tmp"
grep -q '^ext.rootfs_quick.health' "$V73_ACTIONS_FILE.tmp"
sdk_register_workflows
[ -r "$V74_PIPELINE_DIR/ext-system_report-inventory.workflow" ]
sdk_disable system_report
grep -q '^system_report.*disabled' "$V75_MODULE_INDEX"
sdk_enable system_report
grep -q '^system_report.*enabled' "$V75_MODULE_INDEX"
printf '%s\n' 'v7.5 module SDK tests passed'
