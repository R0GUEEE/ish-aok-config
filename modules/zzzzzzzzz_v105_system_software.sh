#!/bin/sh
# v10.5 host-only package groups and iSH-AOK quick install.

v105_pkg_candidate(){
  key=$1
  case "$PKG_MGR:$key" in
    apt:build-essential) printf 'build-essential';; apk:build-essential) printf 'build-base';; pacman:build-essential) printf 'base-devel';; dnf:build-essential|yum:build-essential) printf 'gcc gcc-c++ make';; xbps:build-essential) printf 'base-devel';; emerge:build-essential) printf 'sys-devel/gcc sys-devel/make';;
    apt:dns) printf 'dnsutils';; apk:dns) printf 'bind-tools';; pacman:dns) printf 'bind';; dnf:dns|yum:dns) printf 'bind-utils';; xbps:dns) printf 'bind-utils';; emerge:dns) printf 'net-dns/bind-tools';;
    apt:ping) printf 'iputils-ping';; apk:ping|pacman:ping|dnf:ping|yum:ping|xbps:ping) printf 'iputils';; emerge:ping) printf 'net-misc/iputils';;
    apt:fd) printf 'fd-find';; apk:fd|pacman:fd|dnf:fd|yum:fd|xbps:fd) printf 'fd';; emerge:fd) printf 'sys-apps/fd';;
    apt:bat) printf 'bat';; apk:bat|pacman:bat|dnf:bat|yum:bat|xbps:bat) printf 'bat';; emerge:bat) printf 'sys-apps/bat';;
    apt:ninja) printf 'ninja-build';; apk:ninja|pacman:ninja|dnf:ninja|yum:ninja|xbps:ninja) printf 'ninja';; emerge:ninja) printf 'dev-build/ninja';;
    apt:openssh) printf 'openssh-client openssh-server';; apk:openssh|pacman:openssh|dnf:openssh|yum:openssh|xbps:openssh) printf 'openssh';; emerge:openssh) printf 'net-misc/openssh';;
    apt:python-venv) printf 'python3-venv';; apk:python-venv) printf 'py3-virtualenv';; pacman:python-venv) printf 'python-virtualenv';; dnf:python-venv|yum:python-venv) printf 'python3-virtualenv';; xbps:python-venv) printf 'python3-virtualenv';; emerge:python-venv) printf 'dev-python/virtualenv';;
    apt:netcat) printf 'netcat-openbsd';; apk:netcat) printf 'netcat-openbsd';; pacman:netcat) printf 'openbsd-netcat';; dnf:netcat|yum:netcat) printf 'nmap-ncat';; xbps:netcat) printf 'openbsd-netcat';; emerge:netcat) printf 'net-analyzer/netcat';;
    apt:yq) printf 'yq';; apk:yq|pacman:yq|dnf:yq|yum:yq|xbps:yq) printf 'yq';; emerge:yq) printf 'app-misc/yq';;
    apt:xz) printf 'xz-utils';; apk:xz|pacman:xz|dnf:xz|yum:xz|xbps:xz) printf 'xz';; emerge:xz) printf 'app-arch/xz-utils';;
    *:gzip) printf 'gzip';;
    *:*) printf '%s' "$key";;
  esac
}

v105_pkg_available(){
  p=$1
  case $PKG_MGR in
    apt) apt-cache show "$p" >/dev/null 2>&1;;
    apk) apk search -x "$p" 2>/dev/null | grep -q .;;
    pacman) pacman -Si "$p" >/dev/null 2>&1;;
    dnf|yum) "$PKG_MGR" -q list --available "$p" >/dev/null 2>&1 || "$PKG_MGR" -q list installed "$p" >/dev/null 2>&1;;
    xbps) xbps-query -Rs "^${p}-[0-9]" 2>/dev/null | grep -q . || xbps-query "$p" >/dev/null 2>&1;;
    emerge) emerge -s "^${p}$" 2>/dev/null | grep -q '\*';;
    *) return 1;;
  esac
}

v105_pkg_installed(){
  p=$1
  case $PKG_MGR in
    apt) dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed';;
    apk) apk info -e "$p" >/dev/null 2>&1;; pacman) pacman -Q "$p" >/dev/null 2>&1;;
    dnf|yum) rpm -q "$p" >/dev/null 2>&1;; xbps) xbps-query "$p" >/dev/null 2>&1;;
    emerge) qlist -IC "$p" >/dev/null 2>&1 2>/dev/null || equery list "$p" >/dev/null 2>&1;;
    *) return 1;;
  esac
}

v105_expand_keys(){
  for key in "$@"; do
    for p in $(v105_pkg_candidate "$key"); do printf '%s\n' "$p"; done
  done | awk '!seen[$0]++'
}

v105_install_keys(){
  title=$1; shift
  available= skipped= installed=
  for p in $(v105_expand_keys "$@"); do
    if v105_pkg_installed "$p"; then installed="$installed $p"
    elif v105_pkg_available "$p"; then available="$available $p"
    else skipped="$skipped $p"
    fi
  done
  summary="Already installed:${installed:- none}\n\nTo install:${available:- none}\n\nUnavailable and skipped:${skipped:- none}"
  ui_yesno "$title" "$summary\n\nContinue?" || return 0
  rc=0
  [ -z "$available" ] || pkg_install $available || rc=1
  ui_text "$title" "Installation finished.\n\nInstalled or attempted:${available:- none}\nAlready present:${installed:- none}\nSkipped:${skipped:- none}"
  return "$rc"
}

v105_quick_install(){
  v105_install_keys 'iSH-AOK Essentials' \
    bash bash-completion dialog whiptail curl wget git rsync tar gzip xz zstd unzip zip \
    ca-certificates openssh sudo file less procps findutils grep sed gawk coreutils util-linux \
    iproute2 ping dns
}

v105_group_install(){
  group=$1
  case $group in
    essentials) set -- bash bash-completion dialog whiptail curl wget git rsync tar gzip xz zstd unzip zip ca-certificates openssh sudo file less procps findutils grep sed gawk coreutils util-linux iproute2 ping dns;;
    developer) set -- build-essential gcc g++ make cmake pkg-config autoconf automake libtool meson ninja python3 python3-pip python-venv rust cargo gdb strace ltrace sqlite3;;
    network) set -- iproute2 ping dns net-tools curl wget openssh tcpdump traceroute mtr netcat openssl;;
    editors) set -- nano vim neovim emacs micro helix;;
    shells) set -- bash zsh fish dash nushell starship bash-completion;;
    terminal) set -- btop htop fastfetch ncdu eza bat fd ripgrep fzf zoxide jq yq tmux screen mc lf yazi nnn tere tree less file;;
    archive) set -- tar gzip xz zstd zip unzip bzip2 p7zip rsync cpio;;
    filesystem) set -- util-linux e2fsprogs dosfstools parted rsync tree ncdu file findutils;;
    monitoring) set -- procps htop btop lsof strace sysstat iotop iftop nmon;;
    databases) set -- sqlite3 postgresql-client mariadb-client redis-tools;;
    languages) set -- python3 python3-pip python-venv nodejs npm rust cargo golang ruby perl lua;;
    builders) set -- debootstrap qemu-user-static binfmt-support build-essential cmake meson ninja git rsync tar xz zstd;;
    *) return 1;;
  esac
  v105_install_keys "Install $group packages" "$@"
}

v105_select_group_packages(){
  group=$1
  case $group in
    editors) options="nano Nano on vim Vim on neovim Neovim off emacs Emacs off micro Micro off helix Helix off";;
    shells) options="bash Bash on zsh Zsh off fish Fish off dash Dash off nushell Nushell off starship Starship off bash-completion Bash-completion on";;
    terminal) options="btop btop off htop htop on fastfetch Fastfetch off ncdu ncdu on eza eza off bat bat off fd fd off ripgrep ripgrep on fzf fzf on zoxide zoxide off jq jq on yq yq off tmux tmux on screen Screen off mc Midnight-Commander off lf lf off yazi Yazi off nnn nnn off tere tere off";;
    developer) options="build-essential Build-toolchain on cmake CMake on meson Meson off ninja Ninja on python3 Python3 on python3-pip pip on python-venv Virtualenv on rust Rust off cargo Cargo off gdb GDB on strace strace on ltrace ltrace off sqlite3 SQLite on";;
    network) options="iproute2 iproute2 on ping Ping on dns DNS-tools on net-tools net-tools off openssh OpenSSH on tcpdump tcpdump off traceroute traceroute off mtr mtr off netcat Netcat off openssl OpenSSL on";;
    *) return 1;;
  esac
  # shellcheck disable=SC2086
  selected=$(ui_checklist "Select $group packages" 'Choose packages to install. Unavailable packages will be skipped.' $options) || return 0
  [ -n "$selected" ] || return 0
  # ui_checklist emits one key per line; command substitution normalizes to spaces.
  v105_install_keys "Install selected $group packages" $selected
  case $group in editors) v105_post_editor_setup;; shells) v105_post_shell_setup;; esac
}

v105_post_editor_setup(){
  ui_yesno 'Editor setup' 'Configure the default editor now?' || return 0
  v104_main_scope_call editors_menu
}

v105_post_shell_setup(){
  ui_yesno 'Shell setup' 'Configure an installed shell, prompt, or completion now?' || return 0
  v104_main_scope_call shell_wizards_menu
}

v105_additional_package(){
  p=$(ui_input 'Install package' 'Enter one or more native package names separated by spaces:' '') || return 0
  [ -n "$p" ] || return 0
  v105_install_keys 'Install additional packages' $p
}

v105_package_groups_menu(){
  while :; do
    c=$(ui_menu 'Package Groups' 'Install curated groups on the running iSH-AOK system. Missing repository packages are skipped.' \
      essentials 'iSH-AOK Essentials' developer 'Developer and build tools' network 'Networking tools' editors 'Editors' shells 'Shells and prompts' terminal 'Terminal applications' archive 'Compression and archive tools' filesystem 'Filesystem tools' monitoring 'Monitoring and diagnostics' databases 'Database clients' languages 'Scripting languages' builders 'RootFS builder prerequisites' custom 'Choose individual packages from a group' back 'Back') || return 0
    case $c in
      essentials|developer|network|editors|shells|terminal|archive|filesystem|monitoring|databases|languages|builders) v105_group_install "$c";;
      custom) g=$(ui_menu 'Choose Group' 'Select a package group.' developer Developer network Networking editors Editors shells Shells terminal 'Terminal applications' back Back) || continue; [ "$g" = back ] || v105_select_group_packages "$g";;
      back) return 0;;
    esac
  done
}

v105_system_packages_menu(){
  while :; do
    choice=$(ui_menu 'System Packages' 'These actions affect the running iSH-AOK system only.' \
      quick 'Quick Install: iSH-AOK Essentials' additional 'Install additional packages' groups 'Install curated package groups' manage 'Manage installed packages' remove 'Remove software' search 'Search packages' repositories 'Package repositories' update 'Refresh package indexes' upgrade 'Upgrade installed packages' clean 'Clean package cache' back 'Back') || return 0
    case $choice in
      quick) v105_quick_install;; additional) v105_additional_package;; groups) v105_package_groups_menu;;
      manage) v104_main_scope_call package_menu;;
      remove) p=$(ui_input 'Remove packages' 'Space-separated native package names:' '') || continue; [ -n "$p" ] && v104_main_scope_call pkg_remove $p;;
      search) q=$(ui_input 'Search packages' 'Search term:' '') || continue; [ -n "$q" ] && v104_main_scope_call package_search "$q";;
      repositories) v104_main_scope_call repositories_menu;; update) v104_main_scope_call run_capture 'Package index update' pkg_update;;
      upgrade) v104_main_scope_call run_capture 'System package upgrade' pkg_upgrade;; clean) v104_main_scope_call package_clean;; back) return 0;;
    esac
  done
}

# Replace the v10.4 package submenu with the expanded host-only installer.
v104_system_packages_menu(){ v104_main_scope_call v105_system_packages_menu; }
