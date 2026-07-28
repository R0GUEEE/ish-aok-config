#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v945-navigation.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP"
TMP_DIR=$TMP BACKTITLE=test
. "$BASE/lib/ui.sh"
UI=text
set +e
printf '\n' | ui_menu Child Prompt open Open >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ]
child_menu(){
  choice=$(ui_menu Child Prompt open Open) || {
    _menu_rc=$?
    [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0
    return "$_menu_rc"
  }
  [ "$choice" = open ]
}
parent_menu(){ child_menu; printf 'parent-resumed\n'; }
out=$(printf '\n' | parent_menu 2>/dev/null)
[ "$out" = parent-resumed ]
# Confirm representative menu boundaries use the dedicated Back status.
grep -q 'UI_MENU_BACK_RC' "$BASE/modules/system.sh"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'UI_MENU_BACK_RC' "$BASE/lib/ui.sh"
