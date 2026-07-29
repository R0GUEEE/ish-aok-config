#!/bin/sh
# v11.4 focused shell installation and configuration without plugin menus.

V1140_SHELLS='bash zsh fish'

v1140_shell_label(){
  case $1 in bash) printf Bash;; zsh) printf Zsh;; fish) printf Fish;; *) printf '%s' "$1";; esac
}

v1140_shell_rc(){
  case $1 in
    bash) printf '%s' "$CURRENT_HOME/.bashrc";;
    zsh) printf '%s' "$CURRENT_HOME/.zshrc";;
    fish) printf '%s' "$CURRENT_HOME/.config/fish/config.fish";;
  esac
}

v1140_status(){ command -v "$1" >/dev/null 2>&1 && printf installed || printf 'not installed'; }

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
      install 'Install Starship' enable 'Enable Starship for this shell' disable 'Disable Starship for this shell' \
      config 'Edit the Starship configuration' back Back) || return 0
    case $_c in
      install) command -v starship >/dev/null 2>&1 && ui_msg Starship 'Starship is already installed.' || run_capture 'Installing Starship' pkg_install starship;;
      enable) v1140_starship_enable "$_shell"; ui_msg Starship "Enabled for $(v1140_shell_label "$_shell").";;
      disable) v1140_starship_disable "$_shell"; ui_msg Starship "Disabled for $(v1140_shell_label "$_shell").";;
      config) ensure_template starship "$CURRENT_HOME/.config/starship.toml"; edit_file "$CURRENT_HOME/.config/starship.toml";;
      back) return 0;;
    esac
  done
}

v1140_shell_menu(){
  _shell=$1 _rc_file=$(v1140_shell_rc "$1")
  while :; do
    _c=$(ui_menu "$(v1140_shell_label "$_shell")" \
      "$(printf 'Status: %s\nConfiguration: %s' "$(v1140_status "$_shell")" "$_rc_file")" \
      install "Install $(v1140_shell_label "$_shell")" prompt 'Starship prompt' \
      config 'Edit the shell configuration file' default 'Make this the login shell' back Back) || return 0
    case $_c in
      install) command -v "$_shell" >/dev/null 2>&1 && ui_msg "$(v1140_shell_label "$_shell")" 'Already installed.' || run_capture "Installing $_shell" pkg_install "$_shell";;
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

v1140_shell_configuration_menu(){
  while :; do
    set --
    for _s in $V1140_SHELLS; do set -- "$@" "$_s" "$(v1140_shell_label "$_s") ($(v1140_status "$_s"))"; done
    set -- "$@" aliases 'Shared aliases' scan 'Show installed shells' back Back
    _c=$(ui_menu 'Shell Configuration' 'Choose a shell to install or configure.' "$@") || return 0
    case $_c in
      bash|zsh|fish) v1140_shell_menu "$_c";;
      aliases) ensure_template aliases "$CURRENT_HOME/.aliases";;
      scan) ui_text 'Installed shells' "$(grep -v '^#' /etc/shells 2>/dev/null; for _x in sh ash bash zsh fish dash mksh ksh nu; do command -v "$_x" 2>/dev/null; done | sort -u)";;
      back) return 0;;
    esac
  done
}

v104_shell_editor_menu(){
  while :; do
    choice=$(ui_menu 'Shell, Editor and Terminal' 'Install and configure the interactive environment for the running system.' \
      shells 'Shell installation and configuration' editors 'Editors and editor configuration' \
      terminal 'Terminal applications and multiplexers' back Back) || return 0
    case $choice in shells) v1140_shell_configuration_menu;; editors) editors_menu;; terminal) v1052_terminal_menu;; back) return 0;; esac
  done
}
