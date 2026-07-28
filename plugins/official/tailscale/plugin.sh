#!/bin/sh
tailscale_package='tailscale'
tailscale_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'tailscale'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'tailscale'; return; fi
  echo 'Install package: tailscale' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_tailscale:-0}" = 1 ] || return 0; tailscale_install "$1/rootfs"; }
