#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export HOME=${TMPDIR:-/tmp}/ish-aok-v944-test-$$
trap 'rm -rf "$HOME"' EXIT HUP INT TERM
mkdir -p "$HOME"
export ISH_AOK_CONFIG_ROOT=$BASE
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; [ -r "$f" ] && . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

root="$HOME/custom/location/my-rootfs"
mkdir -p "$root/etc" "$root/bin"
printf '#!/bin/sh\n' >"$root/bin/sh"
chmod +x "$root/bin/sh"
printf 'ID=custom\nNAME=Custom\n' >"$root/etc/os-release"
printf 'root:x:0:0:root:/root:/bin/sh\n' >"$root/etc/passwd"
ui_msg(){ :; }
ui_yesno(){ return 0; }
activity_add(){ :; }
rootfs_anywhere_activate "$root"
canonical=$(CDPATH= cd -P -- "$root" && pwd)
[ "$(active_rootfs)" = "$canonical" ]
grep -Fx "$canonical" "$V944_ROOTFS_RECENT" >/dev/null
[ -r "$(rootfs_meta_file "$canonical")" ]

# Incomplete directories require confirmation and are rejected when declined.
bad="$HOME/not-rootfs"
mkdir -p "$bad"
ui_yesno(){ return 1; }
set +e
rootfs_anywhere_activate "$bad"
rc=$?
set -e
[ "$rc" -ne 0 ]

command -v rootfs_select_anywhere >/dev/null
grep -q '^anywhere|Select from any path|rootfs_select_anywhere|' "$BASE/menus/rootfs_select.menu"
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
printf 'v9.4.4 RootFS anywhere selection: PASS\n'
