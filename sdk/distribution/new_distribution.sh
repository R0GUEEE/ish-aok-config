#!/bin/sh
set -u
ROOT=${ISH_AOK_CONFIG_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)}
. "$ROOT/lib/v11_plugin_sdk.sh"
[ "$#" -ge 5 ] || { echo "usage: $0 ID DEST PACKAGE_MANAGER BACKEND ARCHES" >&2; exit 2; }
v112_distribution_create "$1" "$2" "$3" "$4" "$5"
