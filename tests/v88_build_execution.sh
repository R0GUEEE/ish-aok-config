#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v88-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/home" "$TMP/state" "$TMP/bin"
HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" ISH_AOK_CONFIG_ROOT="$BASE" . "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/*.sh; do . "$f"; done
V87_PROFILE_DIR="$TMP/profiles"; V87_BUILD_PROFILE="$V87_PROFILE_DIR/build.profile"
V88_BUILD_STATE="$TMP/build"; V88_PLAN_DIR="$V88_BUILD_STATE/plans"; V88_RUN_DIR="$V88_BUILD_STATE/runs"; V88_REPORT_DIR="$TMP/reports"
mkdir -p "$V87_PROFILE_DIR" "$V88_PLAN_DIR" "$V88_RUN_DIR" "$V88_REPORT_DIR"
v87_profile_defaults
v87_profile_set "$V87_BUILD_PROFILE" DEST "$TMP/rootfs"
v87_profile_set "$V87_BUILD_PROFILE" BOOTSTRAP build_fs
mkdir -p /tmp/aok-v88-dummy 2>/dev/null || true
plan=$(v88_plan_generate)
grep -q '^preflight' "$plan"
grep -q '^bootstrap' "$plan"
run=test-run; mkdir -p "$V88_RUN_DIR/$run"; cp "$plan" "$V88_RUN_DIR/$run/plan.tsv"; cp "$V87_BUILD_PROFILE" "$V88_RUN_DIR/$run/build.profile"
v88_mark_stage "$run" preflight complete
[ "$(v88_stage_state "$run" preflight)" = complete ]
v88_safe_packages 'bash curl openssh-server'
! v88_safe_packages 'bash;rm'
command -v v88_build_execution_menu >/dev/null
command -v v88_execute_plan >/dev/null
grep -q "execution 'Build execution and recovery'" "$BASE/modules/zz_v88_build_execution.sh"
printf 'v8.8 build execution: PASS\n'
