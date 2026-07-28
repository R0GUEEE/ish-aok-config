#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

case "$VERSION" in 10.[3-9].*|10.1[0-9].*|1[1-9].*) :;; *) exit 1;; esac
[ ! -e "$BASE/menus/projects.menu" ]
! grep -q '^projects|' "$BASE/menus/main.menu"
grep -q '^builder|RootFS Builder|@menu:build|' "$BASE/menus/main.menu"
grep -q '^system|System Configuration|v104_system_configuration_menu|' "$BASE/menus/main.menu"
for fn in v103_build_new v103_quick_profiles_menu v103_health_dashboard v103_fix_rootfs v103_typed_confirm v103_mode_menu; do command -v "$fn" >/dev/null; done
V87_BUILD_PROFILE=${TMPDIR:-/tmp}/v103-profile.$$
: >"$V87_BUILD_PROFILE"
v103_quick_profile_apply developer >/dev/null 2>&1
grep -q '^PACKAGES=.*build-essential' "$V87_BUILD_PROFILE"
rm -f "$V87_BUILD_PROFILE"
v91_menu_validate
