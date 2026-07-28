#!/bin/sh
. "$ISH_AOK_CONFIG_ROOT/backends/common.sh"
backend_bootstrap(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && { v1110_log "$1" bootstrap "dry-run backend=debootstrap"; return 0; }
  dest=$(v1110_profile DEST); release=$(v1110_profile RELEASE); mirror=$(v1110_profile MIRROR); arch=$(v1110_profile ARCH)
  keyring=$(v1101_keyring_for_target "$(v1110_profile DISTRO)" 2>/dev/null || true)
  set -- debootstrap --arch="$arch"; [ -r "$keyring" ] && set -- "$@" --keyring="$keyring"; set -- "$@" "$release" "$dest" "$mirror"; "$@"
}
backend_install_packages(){
  [ "${V1110_DRY_RUN:-0}" = 1 ] && return 0
  packages=$(v1110_profile PACKAGES); [ -n "$packages" ] || return 0
  dest=$(v1110_profile DEST)
  chroot "$dest" sh -c "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $packages"
}
