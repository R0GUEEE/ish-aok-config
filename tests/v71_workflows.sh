#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
for name in aok_v71_workflows_menu rootfs_registry_browser rootfs_health_interactive rootfs_package_native rootfs_snapshot_browser rootfs_diff_viewer rootfs_global_search rootfs_report_generate plugin_marketplace_enhanced build_queue_manager_v71 rootfs_automation_profiles; do
  grep -R "^$name()" "$BASE/modules" >/dev/null || { echo "missing $name"; exit 1; }
done
grep -q "workflows 'Workflow Edition'" "$BASE/modules/aok.sh"
echo 'v7.1 workflow tests passed'
