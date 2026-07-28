#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v942-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/state" "$TMP/work"
export HOME="$TMP" XDG_STATE_HOME="$TMP/state" TMPDIR="$TMP/work" ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done
UI=text
out=$(printf '2\n' | ui_menu Test Prompt one First two Second 2>/dev/null)
[ "$out" = two ] || { echo "text ui contaminated selection: $out" >&2; exit 1; }
out=$(printf '/AOK/roots/custom-test\n' | ui_input Test Path default 2>/dev/null)
[ "$out" = /AOK/roots/custom-test ]
V87_BUILD_PROFILE="$TMP/profile"; export V87_BUILD_PROFILE
v87_profile_defaults
v87_profile_set "$V87_BUILD_PROFILE" DEST /AOK/roots/custom-test
v87_profile_set "$V87_BUILD_PROFILE" DEST_AUTO no
printf '1\n' | v87_profile_choose_arch >/dev/null 2>&1 || true
[ "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)" = /AOK/roots/custom-test ]
v942_tool_audit_report | grep -q 'Tool Audit'
