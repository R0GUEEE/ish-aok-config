#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v89-$$; trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/state"
STATE_DIR=$TMP/state REPORT_DIR=$TMP/reports AOK_PROFILE_DIR=$TMP/profiles V87_PROFILE_DIR=$TMP/profiles V87_BUILD_PROFILE=$TMP/profiles/build.profile
export STATE_DIR REPORT_DIR AOK_PROFILE_DIR V87_PROFILE_DIR V87_BUILD_PROFILE
. "$BASE/lib/core.sh"
. "$BASE/modules/zz_v87_builder_integration.sh"
. "$BASE/modules/zz_v88_build_execution.sh"
. "$BASE/modules/zz_v89_build_profiles.sh"
v87_profile_defaults
v89_install_builtin_presets
[ -f "$V89_PRESET_DIR/devuan-minimal.profile" ]
cp "$V89_PRESET_DIR/devuan-minimal.profile" "$V87_BUILD_PROFILE"
grep -q '^DISTRO=devuan$' "$V87_BUILD_PROFILE"
cp "$V87_BUILD_PROFILE" "$V89_PROFILE_LIBRARY/test.profile"
v87_profile_set "$V89_PROFILE_LIBRARY/test.profile" ARCH amd64
v89_profile_compare_files "$V87_BUILD_PROFILE" "$V89_PROFILE_LIBRARY/test.profile" | grep -q ARCH
v89_build_profiles_report | grep -q 'Build Profiles and Presets'
grep -q -- '--build-profiles-report' "$BASE/modules/main.sh"
! grep -q "command_register build_profiles" "$BASE/lib/dispatcher_v73.sh"
printf 'v8.9 build profiles tests passed\n'
