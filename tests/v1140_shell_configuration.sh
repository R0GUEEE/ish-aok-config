#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP=${TMPDIR:-/tmp}/v1140.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
HOME=$TMP/home; XDG_STATE_HOME=$TMP/state; mkdir -p "$HOME" "$XDG_STATE_HOME"
export ISH_AOK_CONFIG_ROOT="$BASE"
. "$BASE/lib/core.sh"
for f in "$BASE"/lib/*.sh; do [ "$f" = "$BASE/lib/core.sh" ] && continue; . "$f"; done
for f in "$BASE"/modules/package/*.sh "$BASE"/modules/services/*.sh "$BASE"/modules/*.sh; do [ -r "$f" ] && . "$f"; done

MOD=$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_configuration.sh
[ -r "$MOD" ]
for fn in v1140_shell_configuration_menu v1140_shell_menu v1140_prompt_menu \
  v1140_starship_enable v1140_starship_disable v1140_starship_enabled; do
  command -v "$fn" >/dev/null
done
! grep -Eqi 'v1140_(plugins|frameworks|managers)_menu|Plugin managers|Plugins for' "$MOD"
grep -q 'shells) v1140_shell_configuration_menu' "$MOD"

for s in bash zsh fish; do
  v1140_starship_enable "$s"
  v1140_starship_enabled "$s"
  v1140_starship_disable "$s"
  ! v1140_starship_enabled "$s"
done

printf 'v11.4 shell configuration without plugin menus: PASS\n'
