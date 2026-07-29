#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v1130-$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/state" "$TMP/root-a/etc/apt" "$TMP/root-a/bin" "$TMP/root-a/usr/bin" "$TMP/root-a/var/lib/dpkg" "$TMP/root-b/etc/apt" "$TMP/root-b/bin" "$TMP/root-b/usr/bin" "$TMP/root-b/var/lib/dpkg"
for r in "$TMP/root-a" "$TMP/root-b"; do
  cat >"$r/etc/os-release" <<EOT
ID=debian
VERSION_ID=13
VERSION_CODENAME=trixie
EOT
  printf 'root:x:0:0:root:/root:/bin/sh\n' >"$r/etc/passwd"
  printf 'root:x:0:\n' >"$r/etc/group"
  printf '#!/bin/sh\n' >"$r/bin/sh"; chmod +x "$r/bin/sh"; printf '#!/bin/sh\n' >"$r/usr/bin/apt-get"; chmod +x "$r/usr/bin/apt-get"
  printf 'Package: base-files\n' >"$r/var/lib/dpkg/status"
  printf 'deb http://deb.debian.org/debian trixie main\n' >"$r/etc/apt/sources.list"
done
printf 'host-a\n' >"$TMP/root-a/etc/hostname"; printf 'host-b\n' >"$TMP/root-b/etc/hostname"
export ISH_AOK_CONFIG_ROOT=$ROOT V113_STATE_ROOT=$TMP/state V113_LIBRARY=$TMP/state/rootfs/library.tsv V113_WORKSPACES=$TMP/state/workspaces V113_SNAPSHOTS=$TMP/state/snapshots V113_IMAGES=$TMP/state/images/library.tsv V113_REPORTS=$TMP/state/reports V113_DRY_RUN=1
. "$ROOT/lib/v11_workspace_suite.sh"
pass=0 fail=0
ok(){ pass=$((pass+1)); echo "PASS $1"; }
no(){ fail=$((fail+1)); echo "FAIL $1"; }

[ -e "$ROOT/menus/rootfs.menu" ] &&
  grep -q '^guided|Configure and build|v1160_guided|' "$ROOT/menus/rootfs.menu" &&
  [ ! -e "$ROOT/menus/rootfs_manage.menu" ] &&
  [ ! -e "$ROOT/menus/rootfs_select.menu" ] &&
  [ ! -e "$ROOT/menus/rootfs_protect.menu" ] &&
  [ ! -e "$ROOT/menus/rootfs_transfer.menu" ] &&
  ok focused_rootfs_menu_only || no focused_rootfs_menu_only
! grep -Eq "^v113_(rootfs_library|workspace|snapshot|image|lifecycle|management)_menu\(\)" "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzz_v1130_workspace_suite.sh" &&
  ok legacy_rootfs_ui_removed || no legacy_rootfs_ui_removed

v113_init && ok init || no init
id1=$(v113_library_register "$TMP/root-a" alpha minimal) && [ -n "$id1" ] && ok register || no register
id2=$(v113_library_register "$TMP/root-b" beta server) && [ -n "$id2" ] && ok register2 || no register2
[ "$(v113_library_path "$id1")" = "$TMP/root-a" ] && ok lookup || no lookup
wid=$(v113_workspace_create dev "$TMP/root-a" python) && [ -r "$V113_WORKSPACES/$wid/workspace.conf" ] && ok workspace || no workspace
v113_workspace_clone "$wid" devcopy && [ -r "$V113_WORKSPACES/devcopy/workspace.conf" ] && ok clone || no clone
sid=$(v113_snapshot_create "$TMP/root-a" baseline) && v113_snapshot_validate "$sid" && ok snapshot || no snapshot
mkdir -p "$TMP/restore"; v113_snapshot_restore "$sid" "$TMP/restore" && [ -r "$TMP/restore/etc/passwd" ] && ok restore || no restore
report=$(v113_compare "$TMP/root-a" "$TMP/root-b") && grep -q hostname "$report" && ok compare || no compare
validation=$(v113_validate_rootfs "$TMP/root-a") && grep -q 'Overall score:' "$validation" && ok validation || no validation
printf data >"$TMP/test.tar"; iid=$(v113_image_register "$TMP/test.tar") && v113_image_verify "$iid" && ok image || no image
cmd=$(v113_package_apply "$TMP/root-a" install git) && echo "$cmd" | grep -q apt-get && ok package || no package
count=$(find "$ROOT/plugins/official" -name plugin.yaml | wc -l | tr -d ' '); [ "$count" -ge 20 ] && ok plugins || no plugins
for m in "$ROOT"/plugins/official/*/plugin.yaml; do . "$ROOT/lib/v11_plugin_sdk.sh"; v112_plugin_validate "$m" >/dev/null || { no "plugin $(basename "$(dirname "$m")")"; break; }; done
[ "$fail" -eq 0 ] && ok plugin_validation
printf '\n%s passed\n%s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
