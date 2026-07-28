#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v85-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/root/etc/init.d" "$TMP/root/etc/rc2.d" "$TMP/state" "$TMP/reports"
cat >"$TMP/root/etc/os-release" <<EOT
ID=devuan
VERSION_ID=6
EOT
printf '#!/bin/sh\n' >"$TMP/root/etc/init.d/ssh"
chmod +x "$TMP/root/etc/init.d/ssh"
ln -s ../init.d/ssh "$TMP/root/etc/rc2.d/S02ssh"
STATE_DIR=$TMP/state REPORT_DIR=$TMP/reports HOME=$TMP V85_STATE_DIR=$TMP/state/v85 V85_REPORT_DIR=$TMP/reports/v85 ISH_AOK_CONFIG_ROOT=$BASE
export STATE_DIR REPORT_DIR HOME V85_STATE_DIR V85_REPORT_DIR ISH_AOK_CONFIG_ROOT
. "$BASE/lib/core.sh"
. "$BASE/lib/aok_common.sh"
. "$BASE/lib/rootfs_registry.sh"
. "$BASE/lib/distribution_v84.sh"
. "$BASE/lib/service_v85.sh"
[ "$(service_v85_init "$TMP/root")" = sysv ]
service_v85_list "$TMP/root" | grep -qx ssh
service_v85_enabled "$TMP/root" ssh
! service_v85_validate_name '../bad'
out=$TMP/audit.txt
service_v85_boot_audit_to "$TMP/root" "$out"
grep -q 'Init system: sysv' "$out"
grep -q '^ssh$' "$out"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q -- '--service-report' "$BASE/modules/main.sh"
grep -q 'service_orchestration' "$BASE/lib/dispatcher_v73.sh"
printf '%s\n' 'v8.5 service orchestration tests passed'
