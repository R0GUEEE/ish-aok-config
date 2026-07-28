#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v93-test.$$
trap 'rm -rf "$TMP"' EXIT
HOME="$TMP/home"; XDG_STATE_HOME="$TMP/state"; mkdir -p "$HOME" "$XDG_STATE_HOME" "$TMP/artifacts"
. "$BASE/lib/core.sh"
. "$BASE/lib/ui.sh"
. "$BASE/lib/aok_common.sh"
. "$BASE/lib/rootfs_registry.sh"
. "$BASE/lib/rootfs_location_v92.sh"
. "$BASE/lib/build_paths_v93.sh"
. "$BASE/modules/zz_v87_builder_integration.sh"
. "$BASE/modules/zz_v88_build_execution.sh"
. "$BASE/modules/zz_v93_build_paths.sh"
V87_BUILD_PROFILE="$TMP/build.profile"
v93_profile_defaults_extend
[ "$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE)" = repository ]
[ -n "$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR)" ]
v93_source_validate repository 'https://example.invalid/repo'
v93_source_validate archive '/tmp/rootfs.tar.gz'
! v93_source_validate directory 'relative/path' >/dev/null 2>&1
v93_artifact_validate "$TMP/artifacts"
v87_profile_set "$V87_BUILD_PROFILE" CREATE_ARCHIVE yes
plan=$(v88_plan_generate "$TMP/plan.tsv")
grep -q '^artifact' "$plan"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'v93_paths_menu' "$BASE/menus/build_profile.menu"
echo 'v9.3 build paths tests passed'
