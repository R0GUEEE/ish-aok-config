#!/bin/bash
set -eu

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SYSTUI_PROVISION_CONFIG="${TMPDIR:-/tmp}/systui-provision-menu-test.$$"
SYSTUI_PROVISION_TOOL="${TMPDIR:-/tmp}/systui-provision-tool-test.$$"
LIBDIR="$PROJECT_DIR"
export SYSTUI_PROVISION_CONFIG SYSTUI_PROVISION_TOOL LIBDIR
trap 'rm -f -- "$SYSTUI_PROVISION_CONFIG" "$SYSTUI_PROVISION_TOOL"' EXIT

. "$PROJECT_DIR/src/features/ultimate-provision.sh"

# Every package-manager family advertised by the launcher is accepted.
for PM in apt apk pacman dnf yum zypper xbps portage; do
    case "$(script_provision_system_status)" in
        "compatible ($PM)") ;;
        *) echo "not compatible: $PM" >&2; exit 1 ;;
    esac
done
PM=unknown
[ "$(script_provision_system_status)" = "unsupported (no recognized package manager)" ]
unset PM

# The standalone tool contains a package map and skip-and-continue installer
# for every package-manager family exposed by the menu.
for manager in apt apk pacman dnf yum zypper xbps portage; do
    grep -Eq "(^|[|[:space:]])${manager}([|)])" \
        "$PROJECT_DIR/src/provision/provision-ultimate.sh"
done
grep -q 'skipped: \$p (unavailable or installation failed)' \
    "$PROJECT_DIR/src/provision/provision-ultimate.sh"

# Ultimate Provision is a first-class main-menu option.
grep -q 'provision "Ultimate Provision (quick system setup)"' "$PROJECT_DIR/install.sh"
grep -q 'provision)' "$PROJECT_DIR/install.sh"
grep -q 'menu_ultimate_provision' "$PROJECT_DIR/install.sh"
grep -q 'quick "Quick setup (install/update, review, and run)"' \
    "$PROJECT_DIR/src/features/ultimate-provision.sh"

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
injected="${TMPDIR:-/tmp}/systui-provision-menu-injected.$$"
printf 'SCRIPT_PROV_TZ=$(touch %s)\n' "$injected" > "$SYSTUI_PROVISION_CONFIG"
rm -f -- "$injected"
unset SCRIPT_PROV_TZ
script_provision_load
[ ! -e "$injected" ]

[ "$(script_provision_tool_status)" = "not installed" ]
script_provision_install_tool
[ -x "$SYSTUI_PROVISION_TOOL" ]
[ "$(script_provision_tool_status)" = "installed (current)" ]
script_provision_remove_tool
[ ! -e "$SYSTUI_PROVISION_TOOL" ]

echo "ok - Ultimate Provision settings and lifecycle work safely"
