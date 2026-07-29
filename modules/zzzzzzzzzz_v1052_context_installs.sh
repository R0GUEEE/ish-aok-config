#!/bin/sh
# v10.5.2 contextual host-only software installation menus.

v1052_status(){
  command -v "$1" >/dev/null 2>&1 && printf 'installed' || printf 'not installed'
}

v1052_install_and_return(){
  title=$1; shift
  v105_install_keys "$title" "$@"
}

shells_menu(){
  while :; do
    c=$(ui_menu 'Shells, Prompts and Terminal' 'Install missing components or configure the running iSH-AOK system.' \
      install 'Install shells and prompt tools' \
      starship "Starship prompt ($(v1052_status starship))" \
      default 'Change default login shell' \
      bash "Bash ($(v1052_status bash))" \
      zsh "Zsh ($(v1052_status zsh))" \
      fish "Fish ($(v1052_status fish))" \
      frameworks 'Oh My Bash, Oh My Zsh and plugins' \
      completions 'Shell completions and aliases' \
      scan 'Show installed shells' back Back) || return 0
    case $c in
      install) v105_select_group_packages shells;;
      starship) command -v starship >/dev/null 2>&1 || v1052_install_and_return 'Install Starship' starship; starship_menu;;
      default) s=$(ui_input 'Login shell' 'Executable path:' "$(command -v bash 2>/dev/null || command -v sh)") || continue; [ -n "$s" ] && { grep -Fqx "$s" /etc/shells 2>/dev/null || printf '%s\n' "$s"|as_root tee -a /etc/shells >/dev/null; run_capture chsh as_root chsh -s "$s" "$CURRENT_USER"; };;
      bash) command -v bash >/dev/null 2>&1 || v1052_install_and_return 'Install Bash' bash bash-completion; ensure_template bashrc "$CURRENT_HOME/.bashrc";;
      zsh) command -v zsh >/dev/null 2>&1 || v1052_install_and_return 'Install Zsh' zsh; ensure_template zshrc "$CURRENT_HOME/.zshrc";;
      fish) command -v fish >/dev/null 2>&1 || v1052_install_and_return 'Install Fish' fish; shell_wizards_menu;;
      frameworks) plugin_manager_menu shell;;
      completions) shell_config_center;;
      scan) ui_text Shells "$(grep -v '^#' /etc/shells 2>/dev/null; for x in sh ash bash zsh fish dash mksh ksh nu; do command -v "$x" 2>/dev/null; done | sort -u)";;
      back) return 0;;
    esac
  done
}

editors_menu(){
  while :; do
    c=$(ui_menu 'Editors' 'Install an editor directly, then configure it without leaving this menu.' \
      install 'Install editors' default 'Select default editor' \
      nano "Nano ($(v1052_status nano))" vim "Vim ($(v1052_status vim))" \
      nvim "Neovim ($(v1052_status nvim))" micro "Micro ($(v1052_status micro))" \
      helix "Helix ($(v1052_status hx))" emacs "Emacs ($(v1052_status emacs))" \
      scan 'Show installed editors' back Back) || return 0
    case $c in
      install) v105_select_group_packages editors;;
      default) e=$(ui_input Editor 'Command:' nano) || continue; [ -n "$e" ] && replace_block "$CURRENT_HOME/.profile" editor "export EDITOR=$e\nexport VISUAL=$e";;
      nano) command -v nano >/dev/null 2>&1 || v1052_install_and_return 'Install Nano' nano; config_target_menu Nano "$CURRENT_HOME/.nanorc" nano_wizard nanorc;;
      vim) command -v vim >/dev/null 2>&1 || v1052_install_and_return 'Install Vim' vim; config_target_menu Vim "$CURRENT_HOME/.vimrc" vim_wizard vimrc;;
      nvim) command -v nvim >/dev/null 2>&1 || v1052_install_and_return 'Install Neovim' neovim; nvim_full_wizard;;
      micro) command -v micro >/dev/null 2>&1 || v1052_install_and_return 'Install Micro' micro; micro_full_wizard;;
      helix) command -v hx >/dev/null 2>&1 || v1052_install_and_return 'Install Helix' helix; helix_full_wizard;;
      emacs) command -v emacs >/dev/null 2>&1 || v1052_install_and_return 'Install Emacs' emacs; ui_msg Emacs 'Emacs is installed. Use your preferred init.el configuration.';;
      scan) ui_text Editors "$(for x in nano vim nvim micro hx emacs joe; do command -v "$x" 2>/dev/null; done)";;
      back) return 0;;
    esac
  done
}

v1052_network_menu(){
  while :; do
    c=$(ui_menu 'Networking and SSH' 'Configure networking or install missing host networking utilities.' \
      install 'Install networking tools' ssh 'SSH configuration' dns 'DNS configuration' tools 'Network diagnostics' back Back) || return 0
    case $c in install) v105_select_group_packages network;; ssh) ssh_menu;; dns) network_dns_profile;; tools) network_tools_menu;; back) return 0;; esac
  done
}

v1052_development_menu(){
  while :; do
    c=$(ui_menu 'Development Tools' 'Install compilers, languages and developer utilities on the running system.' \
      install 'Install developer and build tools' languages 'Languages and runtimes' compilers 'Compilers and build systems' git 'Git and source tools' back Back) || return 0
    case $c in install) v105_select_group_packages developer;; languages) languages_menu;; compilers) build_compilers_menu;; git) development_menu;; back) return 0;; esac
  done
}

v1052_terminal_menu(){
  while :; do
    c=$(ui_menu 'Terminal Applications' 'Install or configure terminal utilities.' install 'Install terminal applications' files 'Terminal file managers' config 'Terminal tool configuration' back Back) || return 0
    case $c in install) v105_select_group_packages terminal;; files) file_managers_menu;; config) terminal_tools_menu;; back) return 0;; esac
  done
}

v1052_storage_menu(){
  while :; do
    c=$(ui_menu 'Storage, Mounts and Backups' 'Install storage/archive utilities or configure the running system.' \
      installfs 'Install filesystem tools' installarc 'Install archive and compression tools' \
      manage 'Storage, mounts and backup tools' back Back) || return 0
    case $c in installfs) v105_group_install filesystem;; installarc) v105_group_install archive;; manage) storage_backup_menu;; back) return 0;; esac
  done
}

v1052_advanced_system_menu(){
  while :; do
    c=$(ui_menu 'Additional System Tools' 'Install or configure optional tools on the running iSH-AOK system.' \
      development 'Development tools' terminal 'Terminal applications' monitoring 'Monitoring and diagnostics packages' \
      languages 'Scripting languages' legacy 'Other advanced system configuration' back Back) || return 0
    case $c in
      development) v1052_development_menu;; terminal) v1052_terminal_menu;;
      monitoring) v105_group_install monitoring;; languages) v105_group_install languages;;
      legacy) system_menu;; back) return 0;;
    esac
  done
}
