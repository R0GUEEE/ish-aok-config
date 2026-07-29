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
for fn in v1140_shell_configuration_menu v1140_shell_menu v1140_managers_menu \
          v1140_plugins_menu v1140_item_menu v1140_catalog_rows; do
  command -v "$fn" >/dev/null
done

# The environment menu routes shells into the cascade.
grep -q 'shells) v1140_shell_configuration_menu' "$BASE/modules/zzzzzzzzzzzzzzzzzzzzzzzzz_v1140_shell_plugins.sh"

# Every shell offers at least one manager and one plugin.
for s in bash zsh fish; do
  [ "$(v1140_catalog_rows "$s" manager | wc -l)" -ge 1 ]
  [ "$(v1140_catalog_rows "$s" plugin | wc -l)" -ge 1 ]
done

# Catalog integrity: every entry is complete and classified.
for f in "$BASE"/plugins/catalog/*.plugin; do
  id=$(basename "$f" .plugin)
  for k in name tool kind url dest adapter; do
    [ -n "$(plugin_get_field "$id" "$k")" ] || { printf 'missing %s in %s\n' "$k" "$id" >&2; exit 1; }
  done
  case $(plugin_get_field "$id" kind) in
    manager|plugin|app) :;;
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

printf 'v11.4 shell plugin cascade tests passed\n'
