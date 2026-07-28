#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MOD=$BASE/modules/zzzzzzzzzzz_v106_package_managers.sh
[ -f "$MOD" ]
grep -q "v106_package_managers_menu" "$MOD"
grep -q "Package managers and configuration" "$MOD"
grep -q "Install optional package managers (multi-select)" "$MOD"
grep -q "apt-fast Configuration" "$MOD"
grep -q "Scoop is a Windows package manager" "$MOD"
grep -q "v104_system_packages_menu(){ v104_main_scope_call v106_system_packages_menu; }" "$MOD"
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
sh -n "$MOD"
printf 'v10.6.0 package managers: PASS\n'
