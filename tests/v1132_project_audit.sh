#!/bin/sh
set -u
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)
pass=0 fail=0
ok(){ printf 'PASS %s\n' "$1"; pass=$((pass+1)); }
bad(){ printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

[ "$("$BASE/ish-aok-config" --version)" = 'iSH-AOK Config 11.3.2' ] && ok version || bad version
"$BASE/ish-aok-config" --help | grep -q -- '--software-catalog-audit' && ok help_catalog || bad help_catalog
"$BASE/ish-aok-config" --help | grep -q -- '--sdk-self-test' && ok help_sdk || bad help_sdk
if "$BASE/ish-aok-config" --not-a-real-option >/tmp/v1132.out.$$ 2>/tmp/v1132.err.$$; then bad unknown_option; else
  [ "$?" -eq 2 ] && grep -q 'Unknown option' /tmp/v1132.err.$$ && ok unknown_option || bad unknown_option
fi
rm -f /tmp/v1132.out.$$ /tmp/v1132.err.$$
out=$(printf '\n' | TERM=dumb "$BASE/ish-aok-config" 2>&1 || true)
printf '%s' "$out" | grep -Fq '\nActive RootFS:' && bad newline_render || ok newline_render
"$BASE/ish-aok-config" --software-catalog-audit >/dev/null && ok catalog_audit || bad catalog_audit
"$BASE/ish-aok-config" --sdk-self-test >/dev/null && ok sdk_self_test || bad sdk_self_test
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
