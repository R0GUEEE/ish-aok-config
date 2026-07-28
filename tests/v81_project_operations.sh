#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'rootfs_project_activate' "$BASE/modules/platform_v80.sh"
grep -q 'rootfs_project_import' "$BASE/modules/platform_v80.sh"
grep -q 'build_recipe_validate_file' "$BASE/modules/platform_v80.sh"
grep -q 'multi_rootfs_inventory_report' "$BASE/modules/platform_v80.sh"
grep -q 'plugin_repo_install_verified' "$BASE/modules/platform_v80.sh"
grep -q 'remote_profile_add' "$BASE/modules/platform_v80.sh"
"$BASE/ish-aok-config" --platform-report >/tmp/ish-aok-v81-report.txt
grep -q 'Project Operations' /tmp/ish-aok-v81-report.txt
printf '%s\n' 'v8.1 project operations test passed'
