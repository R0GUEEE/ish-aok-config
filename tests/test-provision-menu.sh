#!/bin/bash
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SYSTUI_PROVISION_CONFIG="${TMPDIR:-/tmp}/systui-provision-menu-test.$$"
export SYSTUI_PROVISION_CONFIG
trap 'rm -f -- "$SYSTUI_PROVISION_CONFIG"' EXIT

. "$PROJECT_DIR/src/features/provision-system.sh"

SCRIPT_PROV_TZ=UTC
SCRIPT_PROV_USER=tester
SCRIPT_PROV_HOST=test-node
SCRIPT_PROV_NOPASS=1
script_provision_save

unset SCRIPT_PROV_TZ SCRIPT_PROV_USER SCRIPT_PROV_HOST SCRIPT_PROV_NOPASS
script_provision_load

[ "$SCRIPT_PROV_TZ" = UTC ]
[ "$SCRIPT_PROV_USER" = tester ]
[ "$SCRIPT_PROV_HOST" = test-node ]
[ "$SCRIPT_PROV_NOPASS" = 1 ]

# Configuration is parsed as data; it is never evaluated as shell code.
printf 'SCRIPT_PROV_TZ=$(touch /tmp/systui-provision-menu-injected)\n' > "$SYSTUI_PROVISION_CONFIG"
rm -f /tmp/systui-provision-menu-injected
unset SCRIPT_PROV_TZ
script_provision_load
[ ! -e /tmp/systui-provision-menu-injected ]

echo "ok - provision menu settings round-trip safely"
