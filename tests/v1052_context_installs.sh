#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
M="$ROOT/modules/zzzzzzzzzz_v1052_context_installs.sh"
V="$ROOT/modules/zzzzzzzzz_v105_system_software.sh"
[ -f "$M" ]
grep -q "Install shells and prompt tools" "$M"
grep -q "Install editors" "$M"
grep -q "Install networking tools" "$M"
grep -q "Install developer and build tools" "$M"
grep -q "Install terminal applications" "$M"
grep -q "Install Starship" "$M"
grep -q "Install Nano" "$M"
# v10.5.2 must use one package-manager transaction, not one transaction per package.
! grep -q 'for p in \$available; do pkg_install' "$V"
grep -q 'pkg_install \$available' "$V"
# Main-system scope routes use contextual networking/development menus.
grep -q 'v1052_network_menu' "$ROOT/modules/zzzzzzzz_v104_scope_split.sh"
grep -q 'v1052_storage_menu' "$ROOT/modules/zzzzzzzz_v104_scope_split.sh"
grep -q 'v1052_advanced_system_menu' "$ROOT/modules/zzzzzzzz_v104_scope_split.sh"
printf 'PASS\n'
