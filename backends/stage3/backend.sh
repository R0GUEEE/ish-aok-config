#!/bin/sh
. "$ISH_AOK_CONFIG_ROOT/backends/common.sh"
backend_bootstrap(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && { v1110_log "$1" bootstrap "dry-run backend=stage3"; return 0; }
  v1110_log "$1" bootstrap 'Gentoo stage3 requires a configured local or cached stage3 archive'; return 1
}
backend_install_packages(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  packages=$(v1110_profile PACKAGES); [ -n "$packages" ] || return 0
  dest=$(v1110_profile DEST)
  return 0
}
