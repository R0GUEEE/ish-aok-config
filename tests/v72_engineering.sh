#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
for name in overlay_studio_v72 migration_studio_v72 compatibility_deep_report_v72 boot_studio_v72 rootfs_diff_advanced_v72 automation_scheduler_v72 v72_engineering_menu; do
  grep -R "^$name()" "$BASE/modules" >/dev/null || { echo "missing $name"; exit 1; }
done
grep -q "engineering 'System engineering tools'" "$BASE/modules/aok_v71_workflows.sh"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q -- '--automation' "$BASE/ish-aok-config"
echo 'v7.2 engineering tests passed'
