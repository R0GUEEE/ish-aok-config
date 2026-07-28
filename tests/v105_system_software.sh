#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE HOME=${TMPDIR:-/tmp}/ish-aok-v105-home.$$ XDG_STATE_HOME=$HOME/state
mkdir -p "$HOME"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
for fn in v105_quick_install v105_group_install v105_select_group_packages v105_additional_package v105_package_groups_menu v105_system_packages_menu v105_pkg_available v105_pkg_installed; do command -v "$fn" >/dev/null; done
PKG_MGR=apt
[ "$(v105_pkg_candidate dns)" = dnsutils ]
[ "$(v105_pkg_candidate build-essential)" = build-essential ]
PKG_MGR=apk
[ "$(v105_pkg_candidate dns)" = bind-tools ]
[ "$(v105_pkg_candidate build-essential)" = build-base ]
grep -q "Quick Install: iSH-AOK Essentials" "$BASE/modules/zzzzzzzzz_v105_system_software.sh"
grep -q "Package repositories" "$BASE/modules/zzzzzzzzz_v105_system_software.sh"
sh -n "$BASE/modules/zzzzzzzzz_v105_system_software.sh"
rm -rf "$HOME"
printf 'v10.5 system software installer: PASS\n'
