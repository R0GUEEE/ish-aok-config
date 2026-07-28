#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
apps=$root/modules/plugin_apps.sh
manager=$root/modules/plugin_manager.sh
for token in \
    "Enable Oh My Bash plugins" \
    "Enable Oh My Zsh plugins" \
    "Enable Bash-it components" \
    "Enable Fisher plugins" \
    "Enable Vim plugins" \
    "Enable Neovim plugins" \
    "Enable Tmux plugins" \
    "Enable nnn plugins" \
    "Enable Micro plugins" \
    "Enable lf integrations"
do
    grep -Fq "$token" "$apps" || { echo "missing checklist: $token" >&2; exit 1; }
done
grep -Fq "manual entry is reserved for custom Git plugins" "$manager" || {
    echo 'generic plugin menu still lacks selectable-routing notice' >&2
    exit 1
}
! grep -Fq "Space-separated plugin names:" "$manager" || {
    echo 'manual framework plugin entry still present' >&2
    exit 1
}
echo 'plugin-selection: ok'
