#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v86-$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/root/usr/bin" "$TMP/root/etc/apt/sources.list.d" "$TMP/root/etc/apt/preferences.d" "$TMP/state" "$TMP/reports"
printf '#!/bin/sh\n' >"$TMP/root/usr/bin/apt-get"
chmod +x "$TMP/root/usr/bin/apt-get"
printf 'deb [trusted=yes] http://example.invalid stable main\n' >"$TMP/root/etc/apt/sources.list"
STATE_DIR=$TMP/state REPORT_DIR=$TMP/reports ISH_AOK_CONFIG_ROOT=$BASE
export STATE_DIR REPORT_DIR ISH_AOK_CONFIG_ROOT
. "$BASE/lib/distribution_v84.sh"
. "$BASE/lib/repository_v86.sh"
[ "$(repo_v86_manager "$TMP/root")" = apt ]
repo_v86_files "$TMP/root" | grep -q '/etc/apt/sources.list'
repo_v86_audit "$TMP/root" >"$TMP/audit"
grep -q 'trusted=yes bypass' "$TMP/audit"
grep -q 'unencrypted transport' "$TMP/audit"
snap=$(repo_v86_snapshot "$TMP/root")
[ -s "$snap" ]
out=$(repo_v86_report "$TMP/root")
grep -q '8.6.0' "$out"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'repository_policy' "$BASE/lib/dispatcher_v73.sh"
grep -q -- '--repository-report' "$BASE/modules/main.sh"
echo 'v8.6 repository policy tests passed'
