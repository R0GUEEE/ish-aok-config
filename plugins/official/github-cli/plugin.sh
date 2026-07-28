#!/bin/sh
github_cli_package='gh'
github_cli_install(){
  _root=${1:-/}
  if command -v v113_package_apply >/dev/null 2>&1 && [ "$_root" != / ]; then v113_package_apply "$_root" install 'gh'; return; fi
  if command -v pkg_install >/dev/null 2>&1; then pkg_install 'gh'; return; fi
  echo 'Install package: gh' >&2; return 1
}
plugin_post_bootstrap(){ [ "${V113_ENABLE_PLUGIN_github_cli:-0}" = 1 ] || return 0; github_cli_install "$1/rootfs"; }
