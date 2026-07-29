#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=$($BASE/ish-aok-config --registry-report)
printf '%s\n' "$out" | grep -q '^\[centers\]'
! printf '%s\n' "$out" | grep -q 'AOK Builder Studio'
! printf '%s\n' "$out" | grep -qi 'rootfs builder'
printf '%s\n' "$out" | grep -q '^\[profiles\]'
printf '%s\n' "$out" | grep -q '^\[themes\]'
echo 'registry: ok'
