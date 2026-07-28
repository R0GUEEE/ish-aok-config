#!/bin/sh
ripgrep_package='ripgrep'
ripgrep_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'ripgrep'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'ripgrep'; return; fi
  echo 'Install package: ripgrep' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_ripgrep:-0}" = 1 ] || return 0; ripgrep_install "$1/rootfs"; }
