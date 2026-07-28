#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=${TMPDIR:-/tmp}/v1101-builder-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/state" "$TMP/reports" "$TMP/cache" "$TMP/profile"
export ISH_AOK_CONFIG_ROOT=$BASE
export HOME=$TMP/home
export STATE_DIR=$TMP/state REPORT_DIR=$TMP/reports TMP_DIR=$TMP/tmp
mkdir -p "$HOME" "$TMP_DIR"
PROGRAM=test VERSION=11.0.1 DISTRO_ID=devuan V1101_CACHE_ROOT=$TMP/cache
V87_BUILD_PROFILE=$TMP/profile/active.profile
export PROGRAM VERSION DISTRO_ID V1101_CACHE_ROOT V87_BUILD_PROFILE
. "$BASE/lib/core.sh"
. "$BASE/lib/v11_foundation.sh"
. "$BASE/lib/v11_builder_framework.sh"
v87_profile_get(){ sed -n "s/^$2=//p" "$1" | head -n1; }
v87_profile_set(){ file=$1 key=$2 val=$3; tmp=$file.tmp; [ -f "$file" ] || : >"$file"; awk -F= -v k="$key" '$1!=k{print}' "$file" >"$tmp"; printf '%s=%s\n' "$key" "$val" >>"$tmp"; mv "$tmp" "$file"; }
v87_profile_defaults(){ :; }
cat >"$V87_BUILD_PROFILE" <<EOF_PROFILE
PROFILE_NAME=Test
DISTRO=alpine
RELEASE=v3.22
ARCH=arm64
DEST=$TMP/rootfs
MIRROR=https://dl-cdn.alpinelinux.org/alpine
BOOTSTRAP=sh
PACKAGES=
PACKAGE_SETS=
COMPRESSION=zstd
EOF_PROFILE

packages=$(v1101_packages_for_sets developer alpine)
printf '%s\n' "$packages" | grep -q 'build-base'
printf '%s\n' "$packages" | grep -q 'py3-pip'
! printf '%s\n' "$packages" | grep -q 'build-essential'

v1101_apply_profile developer >/dev/null
grep -q '^PACKAGE_SETS=developer$' "$V87_BUILD_PROFILE"
grep '^PACKAGES=' "$V87_BUILD_PROFILE" | grep -q 'build-base'

v1101_init
[ -d "$TMP/cache/keyrings" ]
[ -d "$TMP/cache/artifacts" ]

report=$(v1101_validation_report)
grep -q '^READY=yes$' "$report"
manifest=$(v1101_manifest_generate)
grep -q '^manifest_version=1$' "$manifest"
grep -q '^distribution=alpine$' "$manifest"
job=$(v1101_queue_add Test)
grep -q '^STATUS=queued$' "$job"

command -v v1101_builder_dashboard >/dev/null 2>&1 || true
printf 'v11.0.1 builder framework regression: PASS\n'
