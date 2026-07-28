#!/bin/sh
wireguard_package='wireguard-tools'
wireguard_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'wireguard-tools'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'wireguard-tools'; return; fi
  echo 'Install package: wireguard-tools' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_wireguard:-0}" = 1 ] || return 0; wireguard_install "$1/rootfs"; }
