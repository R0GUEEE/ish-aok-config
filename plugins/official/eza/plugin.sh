#!/bin/sh
eza_package='eza'
eza_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'eza'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'eza'; return; fi
  echo 'Install package: eza' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_eza:-0}" = 1 ] || return 0; eza_install "$1/rootfs"; }
