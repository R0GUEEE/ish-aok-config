#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for f in "$BASE/lib/core.sh" "$BASE/lib/aok_common.sh" "$BASE/lib/rootfs_registry.sh" "$BASE/modules/aok_v7_studios.sh" "$BASE/modules/aok.sh"; do sh -n "$f"; done
grep -q "studios 'RootFS studios'" "$BASE/modules/aok.sh"
for fn in rootfs_manager_menu rootfs_health_dashboard rootfs_repair_studio chroot_studio_menu rootfs_compatibility_studio rootfs_import_export_studio rootfs_optimization_studio rootfs_reports_studio; do grep -q "^$fn()" "$BASE/modules/aok_v7_studios.sh"; done
printf '%s\n' 'v7-studios: ok'
