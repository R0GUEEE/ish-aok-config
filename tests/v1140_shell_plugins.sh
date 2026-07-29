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

# Cascade functions exist: shell > managers > plugins.
for fn in v1140_shell_configuration_menu v1140_shell_menu v1140_frameworks_menu \
          v1140_managers_menu v1140_plugins_menu v1140_item_menu v1140_catalog_rows; do
  command -v "$fn" >/dev/null
done

# Framework management lives under each individual shell.
grep -q "frameworks) v1140_frameworks_menu" "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_plugins.sh"

# The environment menu routes shells into the cascade.
grep -q 'shells) v1140_shell_configuration_menu' "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_plugins.sh"

# Every shell offers at least one framework, manager and plugin.
for s in bash zsh fish; do
  [ "$(v1140_catalog_rows "$s" framework | wc -l)" -ge 1 ]
  [ "$(v1140_catalog_rows "$s" manager | wc -l)" -ge 1 ]
  [ "$(v1140_catalog_rows "$s" plugin | wc -l)" -ge 1 ]
done

# Frameworks and plugin managers must not overlap.
for s in bash zsh fish; do
  for id in $(v1140_catalog_rows "$s" framework | cut -d'|' -f1); do
    v1140_catalog_rows "$s" manager | cut -d'|' -f1 | grep -Fqx "$id" && {
      printf '%s is both framework and manager\n' "$id" >&2; exit 1; }
  done
done

# Catalog integrity: every entry is complete and classified.
for f in "$BASE"/plugins/catalog/*.plugin; do
  id=$(basename "$f" .plugin)
  for k in name tool kind url dest adapter; do
    [ -n "$(plugin_get_field "$id" "$k")" ] || { printf 'missing %s in %s\n' "$k" "$id" >&2; exit 1; }
  done
  case $(plugin_get_field "$id" kind) in
    framework|manager|plugin|app) :;;
    *) printf 'invalid kind in %s\n' "$id" >&2; exit 1;;
  esac
  case $(plugin_get_field "$id" url) in
    https://github.com/*) :;;
    *) printf 'non-GitHub url in %s\n' "$id" >&2; exit 1;;
  esac
done

# Shell plugins must use an adapter that the framework implements.
for f in "$BASE"/plugins/catalog/*.plugin; do
  id=$(basename "$f" .plugin)
  case $(plugin_get_field "$id" tool) in bash|zsh|fish) :;; *) continue;; esac
  case $(plugin_get_field "$id" adapter) in
    bash_source|zsh_source|fish_source|fish_plugin|framework) :;;
    *) printf 'unsupported adapter in %s\n' "$id" >&2; exit 1;;
  esac
done

# The fish_plugin adapter is wired into both install and disable paths.
grep -q 'fish_plugin)' "$BASE/lib/plugin_framework.sh"

# Starship is managed per shell, under each shell rather than at the top level.
for fn in v1140_prompt_menu v1140_starship_enable v1140_starship_disable v1140_starship_enabled; do
  command -v "$fn" >/dev/null
done
grep -q "prompt) v1140_prompt_menu" "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_plugins.sh"
! grep -q "starship) starship_menu" "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_plugins.sh"

# Enable/disable round-trips for every shell without leaking loop variables.
for s in bash zsh fish; do
  v1140_starship_enable "$s"
  v1140_starship_enabled "$s" || { printf 'starship enable failed for %s\n' "$s" >&2; exit 1; }
  v1140_starship_disable "$s"
  v1140_starship_enabled "$s" && { printf 'starship disable failed for %s\n' "$s" >&2; exit 1; }
  [ "$s" = bash ] || [ "$s" = zsh ] || [ "$s" = fish ] || { printf 'loop variable clobbered\n' >&2; exit 1; }
done

# backup_file must not leak s/n into its caller.
printf 'x\n' >"$HOME/.leakcheck"
s=sentinel; n=sentinel
backup_file "$HOME/.leakcheck"
[ "$s" = sentinel ] && [ "$n" = sentinel ] || { printf 'backup_file leaks globals\n' >&2; exit 1; }

printf 'v11.4 shell plugin cascade tests passed\n'
