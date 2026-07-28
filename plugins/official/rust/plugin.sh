#!/bin/sh
rust_package='rustc'
rust_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'rustc'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'rustc'; return; fi
  echo 'Install package: rustc' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_rust:-0}" = 1 ] || return 0; rust_install "$1/rootfs"; }
