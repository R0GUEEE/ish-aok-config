#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
f="$BASE/modules/zzzzzzzzzzzz_v107_multiselect_packages.sh"
grep -q 'v107_manage_group' "$f"
grep -q 'pkg_upgrade_selected' "$f"
grep -q 'v105_select_group_packages(){ v107_manage_group' "$f"
grep -q 'v105_group_install(){ v107_manage_group' "$f"
grep -q "install 'Install selected packages' remove 'Remove selected packages' update 'Update selected packages'" "$f"
printf 'v10.7 multi-select package tests passed\n'
