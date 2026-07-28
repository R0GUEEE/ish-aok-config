#!/bin/sh
set -u
ROOT=${ISH_AOK_CONFIG_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
. "$ROOT/lib/v11_plugin_sdk.sh"
[ "$#" -ge 2 ] || { echo "usage: $0 ID DEST [NAME] [AUTHOR]" >&2; exit 2; }
v112_plugin_create "$1" "$2" "${3:-$1}" "${4:-unknown}"
