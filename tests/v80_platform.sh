#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'platform_v80_menu' "$BASE/modules/platform_v80.sh"
grep -q 'rootfs_projects_menu' "$BASE/modules/platform_v80.sh"
grep -q 'build_recipes_menu' "$BASE/modules/platform_v80.sh"
grep -q 'multi_rootfs_menu' "$BASE/modules/platform_v80.sh"
grep -q 'plugin_repository_menu' "$BASE/modules/platform_v80.sh"
grep -q -- '--platform-report' "$BASE/modules/main.sh"
"$BASE/ish-aok-config" --platform-report >/tmp/ish-aok-v80-report.txt
 grep -q 'RootFS Platform' /tmp/ish-aok-v80-report.txt
printf '%s\n' 'v8.0 platform test passed'
