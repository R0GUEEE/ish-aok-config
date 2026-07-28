#!/bin/sh
. "$ISH_AOK_CONFIG_ROOT/backends/common.sh"
backend_bootstrap(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && { v1110_log "$1" bootstrap "dry-run backend=xbps"; return 0; }
  xbps-install -S -R "$(v1110_profile MIRROR)" -r "$(v1110_profile DEST)" base-system
}
backend_install_packages(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  packages=$(v1110_profile PACKAGES); [ -n "$packages" ] || return 0
  dest=$(v1110_profile DEST)
  xbps-install -Sy -r "$dest" $packages
}
