#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)
export ISH_AOK_CONFIG_ROOT=$BASE
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

case $VERSION in 9.6.*|9.7.*|9.8.*|9.9.*|10.*|11.*) :;; *) exit 1;; esac
command_registry_build_base
[ "$(command_field rootfs_explorer 4)" = rootfs_explorer_menu ]
command -v rootfs_explorer_menu >/dev/null 2>&1

# Explicit Back must close RootFS Explorer successfully, not reopen it or exit
# the parent workspace. Stub ui_menu to return the dedicated Back status once.
ui_menu(){ return "${UI_MENU_BACK_RC:-90}"; }
set +e
rootfs_explorer_menu
rc=$?
set -e
[ "$rc" -eq 0 ]

# Direct @return dispatch must use the same dedicated status.
set +e
v91_menu_dispatch rootfs back
rc=$?
set -e
[ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ]
