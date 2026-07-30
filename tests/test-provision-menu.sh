#!/bin/bash
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SYSTUI_PROVISION_CONFIG="${TMPDIR:-/tmp}/systui-provision-menu-test.$$"
SYSTUI_PROVISION_TOOL="${TMPDIR:-/tmp}/systui-provision-tool-test.$$"
LIBDIR="$PROJECT_DIR"
export SYSTUI_PROVISION_CONFIG
export SYSTUI_PROVISION_TOOL LIBDIR
trap 'rm -f -- "$SYSTUI_PROVISION_CONFIG" "$SYSTUI_PROVISION_TOOL"' EXIT

. "$PROJECT_DIR/src/features/provision-system.sh"

# Provisioning is reachable only from System Configuration, not Main Menu.
! grep -q 'provision "Provision System' "$PROJECT_DIR/install.sh"
grep -q 'provision.*"Provision tool (install, configure, and manage)"' \
    "$PROJECT_DIR/src/features/sysconfig.sh"
grep -q 'provision).*menu_provision_tool' "$PROJECT_DIR/src/features/sysconfig.sh"

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

[ "$(script_provision_tool_status)" = "not installed" ]
script_provision_install_tool
[ -x "$SYSTUI_PROVISION_TOOL" ]
[ "$(script_provision_tool_status)" = "installed (current)" ]
script_provision_remove_tool
[ ! -e "$SYSTUI_PROVISION_TOOL" ]

echo "ok - provision tool settings and lifecycle work safely"
