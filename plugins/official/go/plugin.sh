#!/bin/sh
go_package='golang'
go_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'golang'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'golang'; return; fi
  echo 'Install package: golang' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_go:-0}" = 1 ] || return 0; go_install "$1/rootfs"; }
