#!/bin/sh
samba_package='samba'
samba_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'samba'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'samba'; return; fi
  echo 'Install package: samba' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_samba:-0}" = 1 ] || return 0; samba_install "$1/rootfs"; }
