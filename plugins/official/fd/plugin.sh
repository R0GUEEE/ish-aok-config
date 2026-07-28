#!/bin/sh
fd_package='fd-find'
fd_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'fd-find'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'fd-find'; return; fi
  echo 'Install package: fd-find' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_fd:-0}" = 1 ] || return 0; fd_install "$1/rootfs"; }
