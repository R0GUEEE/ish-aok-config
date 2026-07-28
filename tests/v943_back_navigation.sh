#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v943-back.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP"
TMP_DIR=$TMP BACKTITLE=test
. "$BASE/lib/ui.sh"

# Text UI: selecting an explicit Back row must return failure and no value.
UI=text
set +e
out=$(printf '2\n' | ui_menu Test Prompt open Open back Back 2>/dev/null)
rc=$?
set -e
[ "$rc" -ne 0 ]
[ -z "$out" ]

# Text UI: blank selection is also Back.
set +e
out=$(printf '\n' | ui_menu Test Prompt open Open 2>/dev/null)
rc=$?
set -e
[ "$rc" -ne 0 ]
[ -z "$out" ]

# Ordinary selections remain unchanged.
out=$(printf '1\n' | ui_menu Test Prompt open Open back Back 2>/dev/null)
[ "$out" = open ]

# dialog and whiptail selections use the same central tag handling.
dialog(){ printf back; }
UI=dialog
set +e
out=$(ui_menu Test Prompt open Open back Back 2>/dev/null)
rc=$?
set -e
[ "$rc" -ne 0 ] && [ -z "$out" ]

whiptail(){ printf '"back"'; }
UI=whiptail
set +e
out=$(ui_menu Test Prompt open Open back Back 2>/dev/null)
rc=$?
set -e
[ "$rc" -ne 0 ] && [ -z "$out" ]

grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'ui_menu_is_back' "$BASE/lib/ui.sh"
