#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pass=0 fail=0
ok(){ pass=$((pass+1)); printf 'PASS %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
"$ROOT/ish-aok-config" --software-catalog-report | grep -q '^nano' && ok 'catalog report' || bad 'catalog report'
"$ROOT/ish-aok-config" --software-catalog-audit > /tmp/v1131-catalog-audit.$$ 2>&1 && ok 'all catalog handlers resolve' || { cat /tmp/v1131-catalog-audit.$$; bad 'all catalog handlers resolve'; }
grep -q '^nano|Editors|Nano|' "$ROOT/data/v11/software-catalog.tsv" && ok 'catalog data present' || bad 'catalog data present'
grep -q 'packages) v105_package_groups_menu' "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzzzz_v1131_catalog_fix.sh" && ok 'package groups route repaired' || bad 'package groups route repaired'
rm -f /tmp/v1131-catalog-audit.$$
[ "$fail" -eq 0 ] || exit 1
printf '%s passed, %s failed\n' "$pass" "$fail"
