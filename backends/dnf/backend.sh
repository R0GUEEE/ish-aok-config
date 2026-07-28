#!/bin/sh
. "$ISH_AOK_CONFIG_ROOT/backends/common.sh"
backend_bootstrap(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && { v1110_log "$1" bootstrap "dry-run backend=dnf"; return 0; }
  dnf -y --installroot="$(v1110_profile DEST)" --releasever="$(v1110_profile RELEASE)" --forcearch="$(v1110_profile ARCH)" install basesystem
}
backend_install_packages(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  packages=$(v1110_profile PACKAGES); [ -n "$packages" ] || return 0
  dest=$(v1110_profile DEST)
  dnf -y --installroot="$dest" install $packages
}
