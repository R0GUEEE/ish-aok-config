#!/bin/sh
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export ISH_AOK_CONFIG_ROOT=$ROOT
TMP=${TMPDIR:-/tmp}/ish-aok-v112-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP"
export V112_PLUGIN_ROOT=$TMP/plugins V112_DISABLED=$TMP/disabled V112_INDEX=$TMP/index.tsv
. "$ROOT/lib/v11_plugin_sdk.sh"
pass=0 fail=0
ok(){ pass=$((pass+1)); echo "PASS: $1"; }
bad(){ fail=$((fail+1)); echo "FAIL: $1"; }

v112_plugin_create sample-plugin "$TMP/sample" 'Sample Plugin' tester && ok 'plugin generator' || bad 'plugin generator'
[ "$(v112_plugin_validate "$TMP/sample/plugin.yaml")" = valid ] && ok 'plugin validation' || bad 'plugin validation'
v112_plugin_install_dir "$TMP/sample" && [ -r "$V112_PLUGIN_ROOT/sample-plugin/plugin.yaml" ] && ok 'plugin installation' || bad 'plugin installation'
v112_plugin_disable sample-plugin; v112_plugin_disabled sample-plugin && ok 'plugin disable' || bad 'plugin disable'
v112_plugin_enable sample-plugin; ! v112_plugin_disabled sample-plugin && ok 'plugin enable' || bad 'plugin enable'
v112_plugin_scan; grep -q '^sample-plugin' "$V112_INDEX" && ok 'plugin discovery' || bad 'plugin discovery'
v112_distribution_create sample-linux "$TMP/dist" apk apk 'arm64,amd64' && ok 'distribution generator' || bad 'distribution generator'
[ "$(v112_distribution_validate "$TMP/dist")" = valid ] && ok 'distribution validation' || bad 'distribution validation'
v112_catalog_report | grep -q github-cli && ok 'catalog report' || bad 'catalog report'
sh -n "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzz_v1120_plugin_runtime.sh" && ok 'runtime syntax' || bad 'runtime syntax'
[ ! -e "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzz_v1120_plugin_sdk.sh" ] && ok 'plugin menus removed' || bad 'plugin menus removed'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
