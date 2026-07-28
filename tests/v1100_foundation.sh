#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ISH_AOK_CONFIG_ROOT=$ROOT
DISTRO_ID=devuan
. "$ROOT/lib/v11_foundation.sh"
[ "$(v11_capability_value rootfs_builder devuan)" = yes ]
[ "$(v11_capability_value apt_fast alpine)" = no ]
v11_supports repository_manager ubuntu
[ "$(v11_build_profile_get standard label)" = Standard ]
v11_catalog_report | grep -q '^nano'
v11_plugin_inventory | grep -q '^example|Example v11 Module|1.0.0|no|'
for fn in v1100_builder_dashboard v1100_software_catalog_menu v1100_plugins_menu; do
  grep -q "^$fn()" "$ROOT/modules/zzzzzzzzzzzzzzzzzz_v1100_foundation.sh"
done
printf 'v11 foundation: PASS\n'
