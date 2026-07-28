#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-config-test.$$
HOME=$TMP/home
XDG_STATE_HOME=$TMP/state
XDG_DATA_HOME=$TMP/data
export HOME XDG_STATE_HOME XDG_DATA_HOME
mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"
ISH_AOK_CONFIG_ROOT=$BASE
export ISH_AOK_CONFIG_ROOT
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] || . "$f"; done
. "$BASE/modules/config_wizards.sh"
. "$BASE/modules/shell_config_tools.sh"
shell_default_body bash recommended >"$TMP/bashrc"
bash -n "$TMP/bashrc"
shell_default_body zsh recommended | grep -q 'HISTFILE='
shell_default_body profile recommended | grep -q 'export PATH'
plugin_list_catalog | grep -q 'oh-my-bash|bash|Oh My Bash'
plugin_list_catalog | grep -q 'lazy-nvim|neovim|lazy.nvim'
rm -rf "$TMP"
printf 'shell/plugin smoke tests passed\n'
