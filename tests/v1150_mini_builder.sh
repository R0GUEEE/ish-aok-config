#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v1150.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
HOME=$TMP/home; XDG_STATE_HOME=$TMP/state; mkdir -p "$HOME" "$XDG_STATE_HOME"
export ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

for fn in v1150_mini_builder_menu v1150_guided_create v1150_features_menu \
          v1150_components_menu v1150_options_menu \
          v1150_template_menu v1150_template_save v1150_template_load \
          v1150_apply_to_profile v1150_build v1150_packages v1150_defaults; do
  command -v "$fn" >/dev/null
done

# The builder dashboard leads with the mini builder.
grep -q "mini) v1150_mini_builder_menu" "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzzz_v1150_mini_builder.sh"

# Defaults describe a genuinely minimal RootFS.
v1150_defaults
[ "$(v1150_get SETS)" = minimal ]
[ -n "$(v1150_get DISTRO)" ] && [ -n "$(v1150_get ARCH)" ] && [ -n "$(v1150_get DEST)" ]

# Package resolution is distro specific: Alpine uses xz, Debian uses xz-utils.
v1150_set DISTRO alpine
printf '%s' "$(v1150_packages)" | grep -qw xz
v1150_set DISTRO debian
printf '%s' "$(v1150_packages)" | grep -qw xz-utils
v1150_set DISTRO alpine

# Selecting more components resolves to more packages, without duplicates.
v1150_set SETS minimal
small=$(v1150_package_count)
v1150_set SETS 'minimal developer'
large=$(v1150_package_count)
[ "$large" -gt "$small" ]
dups=$(v1150_packages | tr ' ' '\n' | sed '/^$/d' | sort | uniq -d)
[ -z "$dups" ] || { printf 'duplicate packages: %s\n' "$dups" >&2; exit 1; }

# Option predicates.
v1150_set OPTIONS 'stripdocs ssh'
v1150_option_on stripdocs
v1150_option_on ssh
v1150_option_on sudo && { printf 'option_on false positive\n' >&2; exit 1; }

# Components and build options share one space-to-select checklist.
ui_checklist(){ printf '%s\n' set_minimal set_recovery opt_nocache opt_network; }
v1150_features_menu
[ "$(v1150_get SETS)" = 'minimal recovery' ]
[ "$(v1150_get OPTIONS)" = 'nocache network' ]

# Template round trip preserves every field.
mkdir -p "$V1150_TEMPLATE_DIR"
v1150_set SETS 'minimal recovery'; v1150_set ARCH x86_64; v1150_set DEST /tmp/rescue-root
{
  printf 'DISTRO=%s\n' "$(v1150_get DISTRO)"
  printf 'RELEASE=%s\n' "$(v1150_get RELEASE)"
  printf 'ARCH=%s\n' "$(v1150_get ARCH)"
  printf 'DEST=%s\n' "$(v1150_get DEST)"
  printf 'SETS=%s\n' "$(v1150_get SETS)"
  printf 'OPTIONS=%s\n' "$(v1150_get OPTIONS)"
} >"$(v1150_template_file roundtrip)"
v1150_set SETS minimal; v1150_set ARCH x86; v1150_set DEST /tmp/other
for k in DISTRO RELEASE ARCH DEST SETS OPTIONS; do
  v=$(sed -n "s/^$k=//p" "$(v1150_template_file roundtrip)" | tail -n 1)
  [ -n "$v" ] && v1150_set "$k" "$v"
done
[ "$(v1150_get SETS)" = 'minimal recovery' ]
[ "$(v1150_get ARCH)" = x86_64 ]
[ "$(v1150_get DEST)" = /tmp/rescue-root ]
v1150_template_list | grep -q '^roundtrip|'

# Empty values are real template values (for example, no optional behaviors).
printf 'DISTRO=alpine\nRELEASE=latest-stable\nARCH=x86\nDEST=/tmp/plain\nSETS=minimal\nOPTIONS=\n' >"$(v1150_template_file empty-options)"
v1150_set OPTIONS archive
ui_menu(){ printf empty-options; }
ui_msg(){ :; }
v1150_template_load
[ -z "$(v1150_get OPTIONS)" ]

# Changing distribution refreshes only untouched defaults and selects a valid
# spelling for iSH's native 32-bit x86 architecture.
v1150_set DISTRO alpine; v1150_set RELEASE latest-stable; v1150_set ARCH x86
v1150_set DEST /AOK/roots/mini-alpine
ui_radiolist(){ case $1 in Distribution) printf debian;; Architecture) printf i386;; esac; }
ui_input(){ printf '%s' "$3"; }
v1150_target_menu
[ "$(v1150_get RELEASE)" = stable ]
[ "$(v1150_get ARCH)" = i386 ]
[ "$(v1150_get DEST)" = /AOK/roots/mini-debian ]

# Publishing to the build profile feeds the existing pipeline.
v1150_set DISTRO alpine; v1150_set DEST /tmp/rescue-root
v1150_apply_to_profile
[ "$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO)" = alpine ]
[ "$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)" = apk ]
[ "$(v1110_profile DEST)" = /tmp/rescue-root ]
[ "$(v1110_backend_name)" = apk ]

printf 'v11.5 mini RootFS builder tests passed\n'
