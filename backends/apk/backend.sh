#!/bin/sh
. "$ISH_AOK_CONFIG_ROOT/backends/common.sh"
backend_bootstrap(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && { v1110_log "$1" bootstrap "dry-run backend=apk"; return 0; }
  dest=$(v1110_profile DEST); mkdir -p "$dest"; apk --root "$dest" --initdb --arch "$(v1110_profile ARCH)" add alpine-base
}
backend_install_packages(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  packages=$(v1110_profile PACKAGES); [ -n "$packages" ] || return 0
  dest=$(v1110_profile DEST)
  apk --root "$dest" add $packages
}
