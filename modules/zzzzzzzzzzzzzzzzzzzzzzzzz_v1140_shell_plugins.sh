#!/bin/sh
# v11.4 cascaded shell configuration:
#   Shell  >  Plugin managers and addons  >  Plugins
#
# Every entry resolves to the existing plugin framework, so installing an item
# clones it from GitHub, records a manifest, and writes a reversible marked
# block into the shell's rc file. Removal reverses both steps.

V1140_SHELLS='bash zsh fish'

v1140_shell_label(){
  case $1 in
    bash) printf 'Bash';;
    zsh) printf 'Zsh';;
    fish) printf 'Fish';;
    *) printf '%s' "$1";;
  esac
}

v1140_shell_rc(){
  case $1 in
    bash) printf '%s' "$CURRENT_HOME/.bashrc";;
    zsh) printf '%s' "$CURRENT_HOME/.zshrc";;
    fish) printf '%s' "$CURRENT_HOME/.config/fish/config.fish";;
  esac
}

v1140_status(){ command -v "$1" >/dev/null 2>&1 && printf installed || printf 'not installed'; }

# Starship is configured per shell, so the shell is already known here and is
# never asked for a second time.
v1140_starship_enabled(){
  case $1 in
    bash) grep -q 'ish-aok-config: starship' "$CURRENT_HOME/.bashrc" 2>/dev/null;;
    zsh) grep -q 'ish-aok-config: starship' "$CURRENT_HOME/.zshrc" 2>/dev/null;;
    fish) [ -f "$CURRENT_HOME/.config/fish/conf.d/starship.fish" ];;
    *) return 1;;
  esac
}

v1140_starship_enable(){
  case $1 in
    bash) replace_block "$CURRENT_HOME/.bashrc" starship 'command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"';;
    zsh) replace_block "$CURRENT_HOME/.zshrc" starship 'command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"';;
    fish) mkdir -p "$CURRENT_HOME/.config/fish/conf.d"; write_file "$CURRENT_HOME/.config/fish/conf.d/starship.fish" 644 'command -q starship; and starship init fish | source';;
  esac
}

v1140_starship_disable(){
  case $1 in
    bash) remove_managed_block "$CURRENT_HOME/.bashrc" starship;;
    zsh) remove_managed_block "$CURRENT_HOME/.zshrc" starship;;
    fish) rm -f "$CURRENT_HOME/.config/fish/conf.d/starship.fish";;
  esac
}

v1140_prompt_menu(){
  _shell=$1
  while :; do
    _state=$(v1140_starship_enabled "$_shell" && printf enabled || printf disabled)
    _c=$(ui_menu "$(v1140_shell_label "$_shell") Prompt" \
      "$(printf 'Starship: %s\nFor %s: %s' "$(v1140_status starship)" "$(v1140_shell_label "$_shell")" "$_state")" \
      install 'Install Starship' \
      enable "Enable Starship for $(v1140_shell_label "$_shell")" \
      disable "Disable Starship for $(v1140_shell_label "$_shell")" \
      config 'Edit the Starship configuration' \
      back 'Back') || { _r=$?; [ "$_r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_r"; }
    case $_c in
      install)
        if command -v starship >/dev/null 2>&1; then
          ui_msg Starship 'Starship is already installed.'
        else
          run_capture 'Installing Starship' pkg_install starship
        fi
        ;;
      enable)
        v1140_starship_enable "$_shell"
        ui_msg Starship "Enabled for $(v1140_shell_label "$_shell"). Start a new shell to see the prompt."
        ;;
      disable)
        v1140_starship_disable "$_shell"
        ui_msg Starship "Disabled for $(v1140_shell_label "$_shell")."
        ;;
      config)
        ensure_template starship "$CURRENT_HOME/.config/starship.toml"
        edit_file "$CURRENT_HOME/.config/starship.toml"
        ;;
      back) return 0;;
    esac
  done
}

# Catalog rows for one shell and kind: "id|name"
v1140_catalog_rows(){
  _shell=$1 _kind=$2
  for _f in "$PLUGIN_CATALOG_DIR"/*.plugin "$USER_PLUGIN_CATALOG"/*.plugin; do
    [ -f "$_f" ] || continue
    _id=${_f##*/}; _id=${_id%.plugin}
    [ "$(plugin_get_field "$_id" tool)" = "$_shell" ] || continue
    [ "$(plugin_get_field "$_id" kind)" = "$_kind" ] || continue
    printf '%s|%s\n' "$_id" "$(plugin_get_field "$_id" name)"
  done | sort -u
}

v1140_mark(){ plugin_installed "$1" && printf '[installed]' || printf '[available]'; }

# One plugin or manager: install, update, disable, remove.
v1140_item_menu(){
  _id=$1
  _name=$(plugin_get_field "$_id" name)
  _url=$(plugin_get_field "$_id" url)
  while :; do
    _state=$(plugin_installed "$_id" && printf 'Installed' || printf 'Not installed')
    _c=$(ui_menu "$_name" "$(printf 'Status: %s\nSource: %s' "$_state" "$_url")" \
      install 'Install or update from GitHub' \
      enable 'Enable in the shell configuration' \
      disable 'Disable (keep files)' \
      remove 'Remove completely' \
      info 'Show catalog entry' \
      back 'Back') || { _rc=$?; [ "$_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_rc"; }
    case $_c in
      install)
        have git || { ui_yesno 'Git required' 'Git is needed to install plugins. Install it now?' && run_capture 'Installing git' pkg_install git || continue; }
        if run_capture "Installing $_name" plugin_install_git "$_id"; then
          ui_msg "$_name" 'Installed and enabled. Start a new shell to load it.'
        else
          ui_msg "$_name" 'Installation failed. Check the log for details.'
        fi
        ;;
      enable) plugin_enable "$_id" && ui_msg "$_name" 'Enabled in the shell configuration.';;
      disable) plugin_disable "$_id" && ui_msg "$_name" 'Disabled. Files were kept for re-enabling.';;
      remove)
        ui_yesno "$_name" 'Remove the configuration block and delete the downloaded files?' || continue
        plugin_remove "$_id"; ui_msg "$_name" 'Removed.'
        ;;
      info) ui_text "$_name" "$(cat "$(plugin_catalog_file "$_id")" 2>/dev/null)";;
      back) return 0;;
    esac
  done
}

# Level 3: the plugins available for one shell.
v1140_plugins_menu(){
  _shell=$1
  while :; do
    set --
    while IFS='|' read -r _id _name; do
      [ -n "$_id" ] || continue
      set -- "$@" "$_id" "$_name $(v1140_mark "$_id")"
    done <<EOF_ROWS
$(v1140_catalog_rows "$_shell" plugin)
EOF_ROWS
    [ "$#" -gt 0 ] || { ui_msg 'Plugins' "No plugins are catalogued for $(v1140_shell_label "$_shell")."; return 0; }
    set -- "$@" installed 'Show installed plugins for this shell' back 'Back'
    _c=$(ui_menu "$(v1140_shell_label "$_shell") Plugins" \
      'Plugins are cloned from GitHub and enabled in the shell configuration.' "$@") \
      || { _rc=$?; [ "$_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_rc"; }
    case $_c in
      back) return 0;;
      installed)
        _out=''
        while IFS='|' read -r _id _name; do
          [ -n "$_id" ] || continue
          plugin_installed "$_id" && _out="$_out$_name\n"
        done <<EOF_INST
$(v1140_catalog_rows "$_shell" plugin)
EOF_INST
        [ -n "$_out" ] && ui_text 'Installed plugins' "$(printf '%b' "$_out")" || ui_msg 'Installed plugins' 'No plugins from this catalog are installed yet.'
        ;;
      *) v1140_item_menu "$_c";;
    esac
  done
}

# Level 2: configuration frameworks for one shell.
# A framework is an opinionated configuration bundle (Oh My Zsh, Bash-it), as
# opposed to a plugin manager, which only fetches and loads plugins.
v1140_frameworks_menu(){
  _shell=$1
  while :; do
    set --
    while IFS='|' read -r _id _name; do
      [ -n "$_id" ] || continue
      set -- "$@" "$_id" "$_name $(v1140_mark "$_id")"
    done <<EOF_ROWS
$(v1140_catalog_rows "$_shell" framework)
EOF_ROWS
    [ "$#" -gt 0 ] || { ui_msg 'Frameworks' "No frameworks are catalogued for $(v1140_shell_label "$_shell")."; return 0; }
    set -- "$@" back 'Back'
    _c=$(ui_menu "$(v1140_shell_label "$_shell") Frameworks" \
      'A framework replaces the shell configuration with an opinionated setup. Installing more than one at a time is not recommended.' "$@") \
      || { _rc=$?; [ "$_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_rc"; }
    case $_c in
      back) return 0;;
      *) v1140_item_menu "$_c";;
    esac
  done
}

# Level 2: plugin managers, addons and the route down to plugins.
v1140_managers_menu(){
  _shell=$1
  while :; do
    set --
    while IFS='|' read -r _id _name; do
      [ -n "$_id" ] || continue
      set -- "$@" "$_id" "$_name $(v1140_mark "$_id")"
    done <<EOF_ROWS
$(v1140_catalog_rows "$_shell" manager)
EOF_ROWS
    set -- "$@" plugins "Plugins for $(v1140_shell_label "$_shell") >" update 'Update all installed plugins' back 'Back'
    _c=$(ui_menu "$(v1140_shell_label "$_shell") Plugin Managers and Addons" \
      'A plugin manager is optional: catalogued plugins install and load without one. Frameworks are managed separately.' "$@") \
      || { _rc=$?; [ "$_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_rc"; }
    case $_c in
      back) return 0;;
      plugins) v1140_plugins_menu "$_shell";;
      update) run_capture 'Updating plugins' plugin_update_all; ui_msg 'Plugins' 'Update finished.';;
      *) v1140_item_menu "$_c";;
    esac
  done
}

# Level 1: one shell.
v1140_shell_menu(){
  _shell=$1
  _rc_file=$(v1140_shell_rc "$_shell")
  while :; do
    _c=$(ui_menu "$(v1140_shell_label "$_shell")" \
      "$(printf 'Status: %s\nConfiguration: %s' "$(v1140_status "$_shell")" "$_rc_file")" \
      install "Install $(v1140_shell_label "$_shell")" \
      frameworks 'Configuration frameworks >' \
      managers 'Plugin managers and addons >' \
      prompt 'Starship prompt >' \
      config 'Edit the shell configuration file' \
      default 'Make this the login shell' \
      back 'Back') || { _r=$?; [ "$_r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_r"; }
    case $_c in
      install)
        if command -v "$_shell" >/dev/null 2>&1; then
          ui_msg "$(v1140_shell_label "$_shell")" "$_shell is already installed."
        else
          run_capture "Installing $_shell" pkg_install "$_shell"
        fi
        ;;
      frameworks) v1140_frameworks_menu "$_shell";;
      managers) v1140_managers_menu "$_shell";;
      prompt) v1140_prompt_menu "$_shell";;
      config) mkdir -p "$(dirname "$_rc_file")" 2>/dev/null || true; edit_file "$_rc_file";;
      default)
        _p=$(command -v "$_shell" 2>/dev/null) || { ui_msg 'Login shell' "$_shell is not installed yet."; continue; }
        ui_yesno 'Login shell' "Set $_p as the login shell for $CURRENT_USER?" || continue
        grep -Fqx "$_p" /etc/shells 2>/dev/null || printf '%s\n' "$_p" | as_root tee -a /etc/shells >/dev/null
        run_capture 'Changing login shell' as_root chsh -s "$_p" "$CURRENT_USER"
        ;;
      back) return 0;;
    esac
  done
}

# Entry point: choose a shell.
v1140_shell_configuration_menu(){
  while :; do
    set --
    for _s in $V1140_SHELLS; do
      set -- "$@" "$_s" "$(v1140_shell_label "$_s") ($(v1140_status "$_s")) >"
    done
    set -- "$@" aliases 'Shared aliases' \
      scan 'Show installed shells' \
      back 'Back'
    _c=$(ui_menu 'Shell Configuration' 'Choose a shell, then its plugin managers, then its plugins.' "$@") \
      || { _r=$?; [ "$_r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_r"; }
    case $_c in
      bash|zsh|fish) v1140_shell_menu "$_c";;
      aliases) ensure_template aliases "$CURRENT_HOME/.aliases";;
      scan) ui_text 'Installed shells' "$(grep -v '^#' /etc/shells 2>/dev/null; for _x in sh ash bash zsh fish dash mksh ksh nu; do command -v "$_x" 2>/dev/null; done | sort -u)";;
      back) return 0;;
    esac
  done
}

# The environment menu now routes shells through the cascade.
v104_shell_editor_menu(){
  while :; do
    choice=$(ui_menu 'Shell, Editor and Terminal' 'Install and configure the interactive environment for the running system.' \
      shells 'Shells, plugin managers and plugins' \
      editors 'Editors and editor configuration' \
      terminal 'Terminal applications and multiplexers' \
      back 'Back') || return 0
    case $choice in
      shells) v1140_shell_configuration_menu;;
      editors) editors_menu;;
      terminal) v1052_terminal_menu;;
      back) return 0;;
    esac
  done
}
