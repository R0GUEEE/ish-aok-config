#!/bin/sh
distrobox_package='distrobox'
distrobox_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'distrobox'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'distrobox'; return; fi
  echo 'Install package: distrobox' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_distrobox:-0}" = 1 ] || return 0; distrobox_install "$1/rootfs"; }
