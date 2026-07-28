#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$BASE/install.sh"
sh -n "$BASE/modules/zzzzzzzz_v104_scope_split.sh"
grep -q 'package_available()' "$BASE/install.sh"
grep -q 'filter_available_packages()' "$BASE/install.sh"
grep -q 'Package not found in enabled repositories; skipping' "$BASE/install.sh"
grep -q 'continuing with the tool installation' "$BASE/install.sh"
grep -q 'v104_system_packages_menu()' "$BASE/modules/zzzzzzzz_v104_scope_split.sh"
grep -q "repositories 'Package repositories'" "$BASE/modules/zzzzzzzz_v104_scope_split.sh"
grep -q 'repositories) v104_main_scope_call repositories_menu' "$BASE/modules/zzzzzzzz_v104_scope_split.sh"
grep -q 'packages) v104_system_packages_menu' "$BASE/modules/zzzzzzzz_v104_scope_split.sh"
printf 'v10.4.2 package availability and repository routing: PASS\n'
