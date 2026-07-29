#!/bin/sh
PLUGIN_STATE_DIR=$STATE_DIR/plugins
PLUGIN_MANIFEST_DIR=$PLUGIN_STATE_DIR/manifests
PLUGIN_DATA_DIR=${XDG_DATA_HOME:-$CURRENT_HOME/.local/share}/ish-aok-config/plugins
PLUGIN_CATALOG_DIR=$ISH_AOK_CONFIG_ROOT/plugins/catalog
USER_PLUGIN_CATALOG=$STATE_DIR/plugin-catalog
mkdir -p "$PLUGIN_MANIFEST_DIR" "$PLUGIN_DATA_DIR" "$USER_PLUGIN_CATALOG" 2>/dev/null || true

plugin_manifest_file(){ printf '%s/%s.manifest' "$PLUGIN_MANIFEST_DIR" "$1"; }
plugin_catalog_file(){ [ -f "$USER_PLUGIN_CATALOG/$1.plugin" ] && printf '%s' "$USER_PLUGIN_CATALOG/$1.plugin" || printf '%s' "$PLUGIN_CATALOG_DIR/$1.plugin"; }
plugin_get_field(){ id=$1; field=$2; f=$(plugin_catalog_file "$id"); [ -f "$f" ] || return 1; sed -n "s/^$field=//p" "$f" | head -n 1; }
plugin_list_catalog(){ for f in "$PLUGIN_CATALOG_DIR"/*.plugin "$USER_PLUGIN_CATALOG"/*.plugin; do [ -f "$f" ] || continue; id=${f##*/}; id=${id%.plugin}; name=$(plugin_get_field "$id" name); tool=$(plugin_get_field "$id" tool); printf '%s|%s|%s\n' "$id" "$tool" "$name"; done; }
plugin_installed(){ [ -f "$(plugin_manifest_file "$1")" ]; }
plugin_install_git(){ id=$1; url=$(plugin_get_field "$id" url); dest=$(plugin_get_field "$id" dest); [ -n "$url" ] && [ -n "$dest" ] || return 1; eval "dest=\"$dest\""; have git || pkg_install git || return 1; mkdir -p "$(dirname "$dest")" 2>/dev/null || return 1; if [ -d "$dest/.git" ]; then git -C "$dest" pull --ff-only; else git clone --depth 1 "$url" "$dest"; fi || return 1; { printf 'id=%s\n' "$id"; printf 'type=git\n'; printf 'url=%s\n' "$url"; printf 'dest=%s\n' "$dest"; printf 'installed=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date)"; } >"$(plugin_manifest_file "$id")"; plugin_post_install "$id"; plugin_enable "$id"; }
plugin_post_install(){ id=$1; adapter=$(plugin_get_field "$id" adapter); mf=$(plugin_manifest_file "$id"); dest=$(sed -n 's/^dest=//p' "$mf"); case $adapter in
 vim_plug_manager)
  mkdir -p "$CURRENT_HOME/.vim/autoload"
  cp "$dest/plug.vim" "$CURRENT_HOME/.vim/autoload/plug.vim" 2>/dev/null || true
  body='call plug#begin("~/.vim/plugged")\n" Plugin declarations managed below\ncall plug#end()'
  replace_block "$CURRENT_HOME/.vimrc" vim-plug-bootstrap "$body"
 ;;
 nvim_lazy_manager)
  mkdir -p "$CURRENT_HOME/.local/share/nvim/lazy" "$CURRENT_HOME/.config/nvim/lua"
  target=$CURRENT_HOME/.local/share/nvim/lazy/lazy.nvim
  [ "$dest" = "$target" ] || { rm -rf "$target"; mv "$dest" "$target" 2>/dev/null || cp -R "$dest" "$target"; }
  body="local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'\nvim.opt.rtp:prepend(lazypath)\nlocal ok, plugins = pcall(require, 'ish_aok_plugins')\nrequire('lazy').setup(ok and plugins or {})"
  replace_block "$CURRENT_HOME/.config/nvim/init.lua" lazy-bootstrap "$body"
  [ -f "$CURRENT_HOME/.config/nvim/lua/ish_aok_plugins.lua" ] || write_file "$CURRENT_HOME/.config/nvim/lua/ish_aok_plugins.lua" 644 'return {\n}'
 ;;
 nnn_plugin)
  mkdir -p "$CURRENT_HOME/.config/nnn/plugins"
  [ -d "$dest/plugins" ] && cp -R "$dest/plugins/." "$CURRENT_HOME/.config/nnn/plugins/"
 ;;
 fish_plugin)
  # Fish autoloads from these directories, so a git plugin is installed by
  # copying its trees into the user's fish configuration.
  for _fd in functions completions conf.d; do
   [ -d "$dest/$_fd" ] || continue
   mkdir -p "$CURRENT_HOME/.config/fish/$_fd"
   cp -R "$dest/$_fd/." "$CURRENT_HOME/.config/fish/$_fd/" 2>/dev/null || true
  done
 ;;
 esac; }
plugin_enable(){ id=$1; adapter=$(plugin_get_field "$id" adapter); case $adapter in
 bash_source) file=$CURRENT_HOME/.bashrc; line=$(plugin_get_field "$id" init); replace_block "$file" "plugin-$id" "$line";;
 zsh_source) file=$CURRENT_HOME/.zshrc; line=$(plugin_get_field "$id" init); replace_block "$file" "plugin-$id" "$line";;
 fish_source) mkdir -p "$CURRENT_HOME/.config/fish/conf.d"; write_file "$CURRENT_HOME/.config/fish/conf.d/ish-aok-$id.fish" 644 "$(plugin_get_field "$id" init)";;
 vim_plug) file=$CURRENT_HOME/.vimrc; repo=$(plugin_get_field "$id" repo); append_plugin_line "$file" vim-plug "Plug '$repo'";;
 nvim_lazy) file=$CURRENT_HOME/.config/nvim/lua/ish_aok_plugins.lua; mkdir -p "$(dirname "$file")"; repo=$(plugin_get_field "$id" repo); append_plugin_line "$file" nvim-lazy "  { '$repo' },";;
 tmux_tpm) file=$CURRENT_HOME/.tmux.conf; repo=$(plugin_get_field "$id" repo); append_plugin_line "$file" tmux-plugins "set -g @plugin '$repo'"; replace_block "$file" tpm-init 'run-shell ~/.tmux/plugins/tpm/tpm';;
 nnn_plugin) :;;
 micro_plugin) have micro && micro -plugin install "$(plugin_get_field "$id" repo)" || true;;
 vim_plug_manager|nvim_lazy_manager) :;;
 generic) :;;
 framework) line=$(plugin_get_field "$id" init); file=$(plugin_get_field "$id" config); eval "file=\"$file\""; replace_block "$file" "plugin-$id" "$line";;
 esac; }
plugin_disable(){ id=$1; adapter=$(plugin_get_field "$id" adapter); case $adapter in
 bash_source) remove_managed_block "$CURRENT_HOME/.bashrc" "plugin-$id";;
 zsh_source) remove_managed_block "$CURRENT_HOME/.zshrc" "plugin-$id";;
 fish_source) rm -f "$CURRENT_HOME/.config/fish/conf.d/ish-aok-$id.fish";;
 fish_plugin)
  _mf=$(plugin_manifest_file "$id"); _dest=$(sed -n 's/^dest=//p' "$_mf" 2>/dev/null)
  [ -n "$_dest" ] && [ -d "$_dest" ] && for _fd in functions completions conf.d; do
   [ -d "$_dest/$_fd" ] || continue
   for _ff in "$_dest/$_fd"/*; do
    [ -e "$_ff" ] || continue
    rm -f "$CURRENT_HOME/.config/fish/$_fd/$(basename "$_ff")"
   done
  done
  ;;
 vim_plug) remove_plugin_line "$CURRENT_HOME/.vimrc" vim-plug "$(plugin_get_field "$id" repo)";;
 nvim_lazy) remove_plugin_line "$CURRENT_HOME/.config/nvim/lua/ish_aok_plugins.lua" nvim-lazy "$(plugin_get_field "$id" repo)";;
 tmux_tpm) remove_plugin_line "$CURRENT_HOME/.tmux.conf" tmux-plugins "$(plugin_get_field "$id" repo)";;
 vim_plug_manager) rm -f "$CURRENT_HOME/.vim/autoload/plug.vim"; remove_managed_block "$CURRENT_HOME/.vimrc" vim-plug-bootstrap;;
 nvim_lazy_manager) rm -rf "$CURRENT_HOME/.local/share/nvim/lazy/lazy.nvim"; remove_managed_block "$CURRENT_HOME/.config/nvim/init.lua" lazy-bootstrap;;
 framework) file=$(plugin_get_field "$id" config); eval "file=\"$file\""; remove_managed_block "$file" "plugin-$id";;
 esac; }
plugin_remove(){ id=$1; plugin_disable "$id"; mf=$(plugin_manifest_file "$id"); [ -f "$mf" ] || return 0; dest=$(sed -n 's/^dest=//p' "$mf"); [ -n "$dest" ] && rm -rf "$dest"; rm -f "$mf"; }
plugin_update(){ id=$1; mf=$(plugin_manifest_file "$id"); [ -f "$mf" ] || return 1; dest=$(sed -n 's/^dest=//p' "$mf"); [ -d "$dest/.git" ] && git -C "$dest" pull --ff-only; }
plugin_update_all(){ for f in "$PLUGIN_MANIFEST_DIR"/*.manifest; do [ -f "$f" ] || continue; id=${f##*/}; id=${id%.manifest}; plugin_update "$id" || true; done; }
append_plugin_line(){ f=$1; block=$2; line=$3; b="# >>> ish-aok-config: $block >>>"; e="# <<< ish-aok-config: $block <<<"; [ -f "$f" ] || write_file "$f" 644 ''; current=$(sed -n "/^$(printf '%s' "$b"|sed 's/[][\\.*^$]/\\&/g')$/,/^$(printf '%s' "$e"|sed 's/[][\\.*^$]/\\&/g')$/p" "$f" 2>/dev/null | sed '1d;$d'); printf '%s\n' "$current" | grep -Fqx "$line" && return; [ -n "$current" ] && current="$current\n$line" || current=$line; replace_block "$f" "$block" "$current"; }
remove_plugin_line(){ f=$1; block=$2; needle=$3; [ -f "$f" ] || return; b="# >>> ish-aok-config: $block >>>"; e="# <<< ish-aok-config: $block <<<"; current=$(sed -n "/^$(printf '%s' "$b"|sed 's/[][\\.*^$]/\\&/g')$/,/^$(printf '%s' "$e"|sed 's/[][\\.*^$]/\\&/g')$/p" "$f" 2>/dev/null | sed '1d;$d' | grep -Fv "$needle"); replace_block "$f" "$block" "$current"; }
