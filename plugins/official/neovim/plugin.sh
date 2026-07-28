#!/bin/sh
neovim_package='neovim'
neovim_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'neovim'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'neovim'; return; fi
  echo 'Install package: neovim' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_neovim:-0}" = 1 ] || return 0; neovim_install "$1/rootfs"; }
