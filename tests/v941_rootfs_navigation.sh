#!/bin/sh
set -u
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export HOME=${HOME:-/tmp}/ish-aok-v941-test-$$
mkdir -p "$HOME"
export ISH_AOK_CONFIG_ROOT=$BASE
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; [ -r "$f" ] && . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

command -v rootfs_registry_select_ui >/dev/null
command -v rootfs_registry_browser >/dev/null
[ ! -e "$BASE/menus/rootfs_select.menu" ]

# Simulate selecting a valid RootFS and ensure it becomes active.
tmp="$HOME/rootfs"
mkdir -p "$tmp/etc" "$tmp/bin"
printf 'NAME=TestLinux\nID=testlinux\n' > "$tmp/etc/os-release"
printf 'root:x:0:0:root:/root:/bin/sh\n' > "$tmp/etc/passwd"
rootfs_register "$tmp"
rootfs_select_registered(){ printf '%s' "$tmp"; }
ui_msg(){ :; }
activity_add(){ :; }
rootfs_registry_select_ui
[ "$(active_rootfs)" = "$tmp" ]

rm -rf "$HOME"
printf 'v9.4.1 RootFS navigation: PASS\n'
