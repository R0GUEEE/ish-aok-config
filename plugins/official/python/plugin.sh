#!/bin/sh
python_package='python3'
python_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'python3'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'python3'; return; fi
  echo 'Install package: python3' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_python:-0}" = 1 ] || return 0; python_install "$1/rootfs"; }
