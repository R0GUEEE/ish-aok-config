#!/bin/sh
podman_package='podman'
podman_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'podman'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'podman'; return; fi
  echo 'Install package: podman' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_podman:-0}" = 1 ] || return 0; podman_install "$1/rootfs"; }
