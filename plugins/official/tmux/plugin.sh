#!/bin/sh
tmux_package='tmux'
tmux_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'tmux'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'tmux'; return; fi
  echo 'Install package: tmux' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_tmux:-0}" = 1 ] || return 0; tmux_install "$1/rootfs"; }
