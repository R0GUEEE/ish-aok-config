#!/bin/sh
fish_package='fish'
fish_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'fish'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'fish'; return; fi
  echo 'Install package: fish' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_fish:-0}" = 1 ] || return 0; fish_install "$1/rootfs"; }
