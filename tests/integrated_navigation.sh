#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
main=$BASE/modules/main.sh
aok=$BASE/modules/aok.sh
! grep -q "6.0 control centers" "$main"
! grep -q "v6_control_center" "$main"
grep -q "software) software_development_menu" "$main"
grep -q "packages) package_center_v6" "$main"
grep -q "shells) shell_center_v6" "$main"
grep -q "storage) storage_center_v6" "$main"
grep -q "backup) backup_restore_center" "$main"
grep -q "advanced) software_development_advanced_menu" "$main"
grep -q "build) aok_build_manage_menu" "$aok"
grep -q "studio) aok_builder_studio" "$aok"
grep -q "advanced) aok_advanced_menu" "$aok"
! grep -q "existing) development_environment_menu" "$BASE/modules/v6_centers.sh"
echo 'integrated-navigation: ok'
