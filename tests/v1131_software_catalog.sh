#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pass=0 fail=0
ok(){ pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
"$ROOT/ish-aok-config" --software-catalog-report | grep -q '^nano' && ok 'catalog report' || bad 'catalog report'
"$ROOT/ish-aok-config" --software-catalog-audit > /tmp/v1131-catalog-audit.$$ 2>&1 && ok 'all catalog handlers resolve' || { cat /tmp/v1131-catalog-audit.$$; bad 'all catalog handlers resolve'; }
grep -q '^nano|Editors|Nano|' "$ROOT/data/v11/software-catalog.tsv" && ok 'catalog data present' || bad 'catalog data present'
[ "$(awk -F '|' '$1 !~ /^#/ && NF >= 8 {count++} END {print count+0}' "$ROOT/data/v11/software-catalog.tsv")" -ge 50 ] && ok 'expanded catalog data' || bad 'catalog is still too small'
grep -q '^openssh-server|Networking|OpenSSH Server|.*|yes|default=openssh-server;apk=openssh;pacman=openssh$' "$ROOT/data/v11/software-catalog.tsv" && ok 'cross-distribution package mappings' || bad 'cross-distribution mappings missing'
grep -q 'packages) v105_package_groups_menu' "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzzzz_v1131_catalog_fix.sh" && ok 'package groups route repaired' || bad 'package groups route repaired'
grep -q "catalog 'Software Catalog" "$ROOT/modules/zzzzzzzzzzzzzzzzz_v112_menu_audit_bugfix.sh" && ok 'catalog moved into system configuration' || bad 'catalog missing from system configuration'
! grep -q "catalog 'Software Catalog'" "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzz_v1130_workspace_suite.sh" && ok 'top-level catalog entry removed' || bad 'duplicate top-level catalog entry remains'
rm -f /tmp/v1131-catalog-audit.$$
[ "$fail" -eq 0 ] || exit 1
printf '%s passed, %s failed\n' "$pass" "$fail"
