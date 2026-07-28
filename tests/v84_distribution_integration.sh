#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
for f in lib/distribution_v84.sh modules/distribution_v84.sh; do [ -s "$BASE/$f" ]; sh -n "$BASE/$f"; done
grep -q 'v84_distribution_integration_menu' "$BASE/modules/main.sh"
grep -q 'command_register distribution' "$BASE/lib/dispatcher_v73.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/root/etc" "$TMP/root/bin" "$TMP/root/etc/init.d" "$TMP/state" "$TMP/reports"
cat >"$TMP/root/etc/os-release" <<'OS'
ID=devuan
ID_LIKE=debian
PRETTY_NAME="Devuan Test"
VERSION_ID=6
OS
: >"$TMP/root/bin/sh"; chmod +x "$TMP/root/bin/sh"
STATE_DIR=$TMP/state REPORT_DIR=$TMP/reports PROGRAM=test VERSION=8.4.0
V84_STATE_DIR=$STATE_DIR/distribution-v84 V84_REPORT_DIR=$REPORT_DIR/distribution-v84
. "$BASE/lib/distribution_v84.sh"
[ "$(v84_normalize_distro devuan debian)" = devuan ]
[ "$(v84_detect_init "$TMP/root")" = sysv ]
[ "$(v84_bootstrap_methods alpine)" = 'apk minirootfs' ]
out=$TMP/report.txt
v84_distribution_report_to "$TMP/root" "$out"
grep -q 'Distribution: devuan' "$out"
grep -q 'Init system: sysv' "$out"
grep -q 'Strong iSH-AOK fit' "$out"
echo 'v8.4 distribution integration tests passed'
