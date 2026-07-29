#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
MOD=$BASE/modules/zzzzzzzzzzzzzzzzz_v112_menu_audit_bugfix.sh
[ -r "$MOD" ]
grep -q '^v112_bug_audit()' "$MOD"
grep -q '^v112_diagnostics_menu()' "$MOD"
# Diagnostics is reached from the main menu; System Configuration no longer
# duplicates it, so assert the canonical main-menu wiring instead.
grep -q "health) v112_diagnostics_menu" "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzz_v1130_workspace_suite.sh"
! grep -q "diagnostics 'Diagnostics and bug check'" "$MOD"
grep -q "stty sane" "$MOD"
grep -q "v111_builder_keyring_preflight" "$MOD"
find "$BASE" -type f \( -name '*.sh' -o -name 'ish-aok-config' \) -exec sh -n {} \;
printf 'v10.12 menu audit and bugfix test passed\n'
