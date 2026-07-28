#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
export ISH_AOK_CONFIG_ROOT=$ROOT
export STATE_DIR=${TMPDIR:-/tmp}/ish-aok-v1110-$$
export REPORT_DIR=$STATE_DIR/reports
export V1110_BUILD_ROOT=$STATE_DIR/builds
export V1110_DRY_RUN=1
. "$ROOT/lib/core.sh"
for f in "$ROOT"/lib/*.sh; do [ "$f" = "$ROOT/lib/core.sh" ] || . "$f"; done
V87_BUILD_PROFILE=$STATE_DIR/profile; export V87_BUILD_PROFILE
mkdir -p "$STATE_DIR"
cat >"$V87_BUILD_PROFILE" <<EOP
DISTRO=debian
RELEASE=trixie
ARCH=arm64
BOOTSTRAP=debootstrap
MIRROR=http://deb.debian.org/debian
DEST=$STATE_DIR/rootfs
PACKAGES=bash curl
PROFILE_NAME=test
EOP
ws=$(v1110_workspace_create test-build)
[ -d "$ws/logs" ]
[ "$(v1110_backend_name)" = debootstrap ]
v1110_pipeline_run "$ws"
[ "$(v1110_state_get "$ws" STATUS)" = complete ]
for s in $V1110_STAGE_ORDER; do [ -f "$ws/stages/$s.done" ]; done
[ -r "$ws/build-plan.txt" ]
grep -q 'Distribution: debian' "$ws/build-plan.txt"
grep -q 'test-build' "$V1110_HISTORY"
printf 'v11.1.0 pipeline regression: PASS\n'
rm -rf "$STATE_DIR"
