#!/bin/sh
bat_package='bat'
bat_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'bat'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'bat'; return; fi
  echo 'Install package: bat' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_bat:-0}" = 1 ] || return 0; bat_install "$1/rootfs"; }
