#!/bin/sh
nodejs_package='nodejs'
nodejs_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'nodejs'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'nodejs'; return; fi
  echo 'Install package: nodejs' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_nodejs:-0}" = 1 ] || return 0; nodejs_install "$1/rootfs"; }
