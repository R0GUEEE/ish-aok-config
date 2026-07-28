#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
for f in lib/package_api_v82.sh lib/rootfs_api_v82.sh lib/ui_components_v82.sh lib/cache_v82.sh modules/reliability_v82.sh; do [ -s "$BASE/$f" ]; sh -n "$BASE/$f"; done
grep -q 'v82_reliability_menu' "$BASE/modules/main.sh"
grep -q '^pkg_refresh()' "$BASE/lib/package_api_v82.sh"
grep -q '^rootfs_api_health()' "$BASE/lib/rootfs_api_v82.sh"
echo 'v8.2 reliability tests passed'
