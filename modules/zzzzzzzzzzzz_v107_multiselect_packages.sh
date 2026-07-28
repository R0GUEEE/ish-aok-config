#!/bin/sh
# v10.7: shared Space-toggle package selection for all host package groups.

v107_group_keys(){
  case $1 in
    essentials) printf '%s\n' bash bash-completion dialog whiptail curl wget git rsync tar gzip xz zstd unzip zip ca-certificates openssh sudo file less procps findutils grep sed gawk coreutils util-linux iproute2 ping dns;;
    developer) printf '%s\n' build-essential gcc g++ make cmake pkg-config autoconf automake libtool meson ninja python3 python3-pip python-venv rust cargo gdb strace ltrace sqlite3;;
    network) printf '%s\n' iproute2 ping dns net-tools curl wget openssh tcpdump traceroute mtr netcat openssl;;
    editors) printf '%s\n' nano vim neovim emacs micro helix;;
    shells) printf '%s\n' bash zsh fish dash nushell starship bash-completion;;
    terminal) printf '%s\n' btop htop fastfetch ncdu eza bat fd ripgrep fzf zoxide jq yq tmux screen mc lf yazi nnn tere tree less file;;
    archive) printf '%s\n' tar gzip xz zstd zip unzip bzip2 p7zip rsync cpio;;
    filesystem) printf '%s\n' util-linux e2fsprogs dosfstools parted rsync tree ncdu file findutils;;
    monitoring) printf '%s\n' procps htop btop lsof strace sysstat iotop iftop nmon;;
    databases) printf '%s\n' sqlite3 postgresql-client mariadb-client redis-tools;;
    languages) printf '%s\n' python3 python3-pip python-venv nodejs npm rust cargo golang ruby perl lua;;
    builders) printf '%s\n' debootstrap qemu-user-static binfmt-support build-essential cmake meson ninja git rsync tar xz zstd;;
    package-managers) printf '%s\n' apt-fast nala pipx flatpak npm cargo;;
    *) return 1;;
  esac
}

v107_label(){
  case $1 in
    build-essential) printf 'Build toolchain';; bash-completion) printf 'Bash completion';;
    python3-pip) printf 'Python pip';; python-venv) printf 'Python virtual environments';;
    openssh) printf 'OpenSSH client and server';; dns) printf 'DNS utilities';; ping) printf 'Ping utilities';;
    fd) printf 'fd file finder';; bat) printf 'bat file viewer';; xz) printf 'XZ utilities';;
    netcat) printf 'Netcat';; iproute2) printf 'iproute2';; util-linux) printf 'util-linux';;
    *) printf '%s' "$1";;
  esac
}

v107_native_installed(){
  key=$1
  for p in $(v105_pkg_candidate "$key"); do v105_pkg_installed "$p" || return 1; done
  return 0
}

v107_build_checklist(){
  group=$1
  set --
  for key in $(v107_group_keys "$group"); do
    native=$(v105_pkg_candidate "$key")
    if v107_native_installed "$key"; then state=on; status=Installed
    else state=off; status='Not installed'
    fi
    label="$(v107_label "$key") — $status"
    [ "$native" = "$key" ] || label="$label [$native]"
    set -- "$@" "$key" "$label" "$state"
  done
  ui_checklist "Manage $group packages" 'Use Space to select multiple packages, then Enter. Installed packages start checked. The next screen chooses Install, Remove, or Update.' "$@"
}

pkg_upgrade_selected(){
  [ "$#" -gt 0 ] || return 0
  case $PKG_MGR in
    apt) _pkg_exec "Updating selected packages: $*" apt-get install --only-upgrade -y "$@";;
    apk) _pkg_exec "Updating selected packages: $*" apk upgrade "$@";;
    pacman) _pkg_exec "Updating selected packages: $*" pacman -S --needed --noconfirm "$@";;
    dnf) _pkg_exec "Updating selected packages: $*" dnf upgrade -y "$@";;
    yum) _pkg_exec "Updating selected packages: $*" yum update -y "$@";;
    xbps) _pkg_exec "Updating selected packages: $*" xbps-install -yu "$@";;
    emerge) _pkg_exec "Updating selected packages: $*" emerge -u "$@";;
    zypper) _pkg_exec "Updating selected packages: $*" zypper --non-interactive update "$@";;
    *) return 1;;
  esac
}

v107_selected_native(){
  for key in "$@"; do v105_pkg_candidate "$key"; printf '\n'; done | awk 'NF && !seen[$0]++'
}

v107_manage_group(){
  group=$1
  selected=$(v107_build_checklist "$group") || return 0
  [ -n "$selected" ] || return 0
  action=$(ui_menu "Manage $group packages" 'Apply one batch operation to all selected packages.' \
    install 'Install selected packages' remove 'Remove selected packages' update 'Update selected packages' back Back) || return 0
  [ "$action" = back ] && return 0
  # Checklist output is newline-separated; command substitution safely normalizes it to words.
  native=$(v107_selected_native $selected)
  [ -n "$native" ] || return 0
  case $action in
    install) v105_install_keys "Install selected $group packages" $selected;;
    remove)
      ui_yesno "Remove selected $group packages" "The following native packages will be removed in one transaction:\n\n$native\n\nContinue?" || return 0
      pkg_remove $native
      ;;
    update)
      ui_yesno "Update selected $group packages" "The following native packages will be updated in one transaction:\n\n$native\n\nContinue?" || return 0
      pkg_upgrade_selected $native
      ;;
  esac
  case $group in editors) [ "$action" = install ] && v105_post_editor_setup;; shells) [ "$action" = install ] && v105_post_shell_setup;; esac
}

# Replace all previous group installers and selectors with the shared manager.
v105_select_group_packages(){ v107_manage_group "$1"; }
v105_group_install(){ v107_manage_group "$1"; }

v105_package_groups_menu(){
  while :; do
    c=$(ui_menu 'Package Groups' 'Select a group, toggle multiple packages with Space, then install, remove, or update them in one transaction.' \
      essentials 'iSH-AOK Essentials' developer 'Developer and build tools' network 'Networking tools' editors Editors shells 'Shells and prompts' terminal 'Terminal applications' archive 'Compression and archive tools' filesystem 'Filesystem tools' monitoring 'Monitoring and diagnostics' databases 'Database clients' languages 'Scripting languages' builders 'RootFS builder prerequisites' back Back) || return 0
    case $c in essentials|developer|network|editors|shells|terminal|archive|filesystem|monitoring|databases|languages|builders) v107_manage_group "$c";; back) return 0;; esac
  done
}
