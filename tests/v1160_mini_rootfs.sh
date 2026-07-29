#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-v1160-$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
export HOME=$TMP/home XDG_STATE_HOME=$TMP/state ISH_AOK_CONFIG_ROOT=$ROOT
mkdir -p "$HOME" "$XDG_STATE_HOME"
. "$ROOT/lib/core.sh"
. "$ROOT/lib/v11_foundation.sh"
. "$ROOT/lib/v11_builder_framework.sh"
V1160_STATE_DIR=$TMP/builder
V1160_CONFIG=$V1160_STATE_DIR/current.conf
V1160_TEMPLATE_DIR=$V1160_STATE_DIR/templates
V1160_LOG_DIR=$V1160_STATE_DIR/logs
. "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzzzzzz_v1160_mini_rootfs.sh"

for fn in v1160_rootfs_menu v1160_guided v1160_distro_menu v1160_init_menu \
  v1160_packages_menu v1160_identity_menu v1160_output_menu v1160_preflight \
  v1160_build v1160_template_save v1160_template_load; do
  command -v "$fn" >/dev/null
done

v1160_defaults
[ "$(v1160_get DISTRO)" = alpine ]
[ "$(v1160_get INIT)" = openrc ]
[ "$(v1160_get PRESETS)" = minimal ]

for distro in debian devuan ubuntu alpine arch fedora void gentoo; do
  v1160_reset_for_distro "$distro"
  [ "$(v1160_get DISTRO)" = "$distro" ]
  [ -n "$(v1160_get RELEASE)" ]
  [ -n "$(v1160_get ARCH)" ]
done

printf '%s' "$(v1160_init_choices debian)" | grep -qw sysvinit
printf '%s' "$(v1160_init_choices debian)" | grep -qw openrc
printf '%s' "$(v1160_init_choices alpine)" | grep -qw openrc
printf '%s' "$(v1160_init_choices void)" | grep -qw runit

v1160_reset_for_distro debian
v1160_set PRESETS 'minimal server'
v1160_set CUSTOM_PACKAGES 'jq tmux'
packages=$(v1160_packages)
printf '%s' "$packages" | grep -qw xz-utils
printf '%s' "$packages" | grep -qw sysvinit-core
printf '%s' "$packages" | grep -qw jq
dups=$(printf '%s' "$packages" | tr ' ' '\n' | sort | uniq -d)
[ -z "$dups" ]
v1160_validate_token_list 'git curl jq'
! v1160_validate_token_list 'git;rm'
v1160_target_safe "$TMP/new-root"
! v1160_target_safe relative-root
! v1160_target_safe /AOK

V1160_ROOT_PASSWORD='never-store-root'
V1160_USER_PASSWORD='never-store-user'
ui_input(){ printf safe-template; }
ui_yesno(){ return 0; }
ui_msg(){ :; }
v1160_template_save
! grep -q 'never-store' "$V1160_TEMPLATE_DIR/safe-template.conf"
! grep -qi '^.*password=' "$V1160_TEMPLATE_DIR/safe-template.conf"

v1160_set TARGET "$TMP/empty-target"
v1160_set COMPRESSION none
v1160_set OUTPUT ''
v1160_set USERNAME ''
v1160_set ROOT_LOGIN locked
V1160_ROOT_PASSWORD= V1160_USER_PASSWORD=
v1160_backend(){ printf sh; }
report=$(v1160_preflight)
printf '%s' "$report" | grep -q 'READY=yes'

grep -q '^rootfs|Mini RootFS Builder|@menu:rootfs|' "$ROOT/menus/main.menu"
grep -q '^rootfs|menu|rootfs|v1160_rootfs_menu|' "$ROOT/config/routes.conf"
grep -q "rootfs 'Mini RootFS Builder'" "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzz_v1130_workspace_suite.sh"
grep -q 'Package presets and custom packages' "$ROOT/modules/zzzzzzzzzzzzzzzzzzzzzzzzzz_v1160_mini_rootfs.sh"

printf 'v11.6 Mini RootFS builder: PASS\n'
