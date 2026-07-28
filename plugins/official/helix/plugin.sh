#!/bin/sh
helix_package='helix'
helix_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'helix'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'helix'; return; fi
  echo 'Install package: helix' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_helix:-0}" = 1 ] || return 0; helix_install "$1/rootfs"; }
