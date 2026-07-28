#!/bin/sh
starship_package='starship'
starship_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'starship'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'starship'; return; fi
  echo 'Install package: starship' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_starship:-0}" = 1 ] || return 0; starship_install "$1/rootfs"; }
