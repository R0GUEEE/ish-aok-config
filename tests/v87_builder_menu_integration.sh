#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v87-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/home" "$TMP/state"
HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" ISH_AOK_CONFIG_ROOT="$BASE" . "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/*.sh; do . "$f"; done
V87_PROFILE_DIR="$TMP/profiles"; V87_BUILD_PROFILE="$V87_PROFILE_DIR/build.profile"; mkdir -p "$V87_PROFILE_DIR"
v87_profile_defaults
[ "$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO)" = devuan ]
[ "$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)" = debootstrap ]
[ "$(v87_profile_get "$V87_BUILD_PROFILE" REGISTER_ROOTFS)" = yes ]
command -v aok_builder_studio >/dev/null
command -v v87_build_profile_wizard >/dev/null
command -v v87_build_execute >/dev/null
grep -q "build 'Build Studio'" "$BASE/modules/zz_v87_builder_integration.sh"
grep -q "rootfs 'RootFS Build Studio'" "$BASE/modules/main.sh"
printf 'v8.7 builder/menu integration: PASS\n'
