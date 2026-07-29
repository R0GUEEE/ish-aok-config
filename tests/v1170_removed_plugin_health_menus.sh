#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MAIN=$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzz_v1130_workspace_suite.sh

! grep -Eq "plugins 'Modules, Plugins|health 'Health & Diagnostics|plugins\) sdk_center|health\) v112_diagnostics_menu" "$MAIN"
! grep -q '^plugins|' "$ROOT/menus/settings.menu"
! grep -Eq '^marketplace\|Plugin marketplace' "$ROOT/catalogs/centers.tsv"
[ ! -e "$ROOT/catalogs/plugin-marketplace.tsv" ]
[ ! -e "$ROOT/modules/plugin_manager.sh" ]
[ ! -e "$ROOT/modules/plugin_apps.sh" ]
[ ! -e "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzz_v1120_plugin_sdk.sh" ]
! grep -Eq 'command_register (plugins|sdk|plugin_repo|compatibility|classic_navigation) ' "$ROOT/lib/dispatcher_v73.sh"
! grep -q 'plugin managers' "$ROOT/lib/dispatcher_v73.sh"
! grep -Eq "plugins 'Extensions and plugins|diagnostics 'Diagnostics and reports" "$ROOT/modules/zzzzzzz_v103_user_friendly.sh"
! grep -q '^v112_diagnostics_menu()' "$ROOT/modules/zzzzzzzzzzzzzzzzz_v112_menu_audit_bugfix.sh"
! grep -q '^v103_health_dashboard()' "$ROOT/modules/zzzzzzz_v103_user_friendly.sh"
! grep -q '^sdk_center()' "$ROOT/lib/sdk/module_sdk.sh"
! grep -q '^sdk_modules_menu()' "$ROOT/lib/sdk/module_sdk.sh"
! grep -Eq "plugins '.*plugin manager|frameworks 'Oh My|plugin_repository_menu" "$ROOT/modules/interactive_wizards.sh" "$ROOT/modules/zzzzzzzzzz_v1052_context_installs.sh" "$ROOT/modules/platform_v80.sh"

printf 'standalone Plugin and Health menus removed: PASS\n'
