#!/bin/sh
git_package='git'
git_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'git'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'git'; return; fi
  echo 'Install package: git' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_git:-0}" = 1 ] || return 0; git_install "$1/rootfs"; }
