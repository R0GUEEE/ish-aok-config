#!/bin/sh
# v10.6 package-manager installation, detection and configuration hub.
# Host-system only: callers must use v104_main_scope_call.

v106_pm_have(){ command -v "$1" >/dev/null 2>&1; }

v106_pm_status(){
  case $1 in
    apt) v106_pm_have apt-get && printf 'installed (native)' || printf 'not installed';;
    apt-fast) v106_pm_have apt-fast && printf 'installed' || { [ "${PKG_MGR:-}" = apt ] && printf 'available add-on' || printf 'unsupported on this host'; }; ;;
    nala) v106_pm_have nala && printf 'installed' || { [ "${PKG_MGR:-}" = apt ] && printf 'optional APT frontend' || printf 'unsupported on this host'; }; ;;
    apk) v106_pm_have apk && printf 'installed (native)' || printf 'not native to this system';;
    pacman) v106_pm_have pacman && printf 'installed (native)' || printf 'not native to this system';;
    dnf) v106_pm_have dnf && printf 'installed (native)' || printf 'not native to this system';;
    yum) v106_pm_have yum && printf 'installed' || printf 'not installed';;
    xbps) v106_pm_have xbps-install && printf 'installed (native)' || printf 'not native to this system';;
    portage) v106_pm_have emerge && printf 'installed (native)' || printf 'not native to this system';;
    zypper) v106_pm_have zypper && printf 'installed (native)' || printf 'not native to this system';;
    scoop) v106_pm_have scoop && printf 'installed' || printf 'Windows only; unavailable inside iSH-AOK';;
    brew) v106_pm_have brew && printf 'installed' || printf 'not installed';;
    flatpak) v106_pm_have flatpak && printf 'installed' || printf 'not installed';;
    snap) v106_pm_have snap && printf 'installed' || printf 'generally incompatible with iSH-AOK';;
    pipx) v106_pm_have pipx && printf 'installed' || printf 'optional Python app manager';;
    cargo) v106_pm_have cargo && printf 'installed' || printf 'optional Rust package manager';;
    npm) v106_pm_have npm && printf 'installed' || printf 'optional Node.js package manager';;
    *) printf 'unknown';;
  esac
}

v106_pm_report(){
  cat <<EOF2
Native package manager: ${PKG_MGR:-unknown}
Distribution: ${DISTRO_ID:-unknown}
Architecture: ${ARCH:-unknown}

APT:       $(v106_pm_status apt)
apt-fast:  $(v106_pm_status apt-fast)
Nala:      $(v106_pm_status nala)
APK:       $(v106_pm_status apk)
Pacman:    $(v106_pm_status pacman)
DNF:       $(v106_pm_status dnf)
YUM:       $(v106_pm_status yum)
XBPS:      $(v106_pm_status xbps)
Portage:   $(v106_pm_status portage)
Zypper:    $(v106_pm_status zypper)
Scoop:     $(v106_pm_status scoop)
Homebrew:  $(v106_pm_status brew)
Flatpak:   $(v106_pm_status flatpak)
Snap:      $(v106_pm_status snap)
Pipx:      $(v106_pm_status pipx)
Cargo:     $(v106_pm_status cargo)
NPM:       $(v106_pm_status npm)
EOF2
}

v106_installable_pm_options(){
  case ${PKG_MGR:-unknown} in
    apt)
      printf '%s\n' \
        "apt-fast apt-fast off" \
        "nala Nala off" \
        "pipx Pipx off" \
        "flatpak Flatpak off" \
        "npm NPM off" \
        "cargo Cargo off"
      ;;
    apk)
      printf '%s\n' "pipx Pipx off" "flatpak Flatpak off" "npm NPM off" "cargo Cargo off";;
    pacman|dnf|yum|xbps|emerge|zypper)
      printf '%s\n' "pipx Pipx off" "flatpak Flatpak off" "npm NPM off" "cargo Cargo off";;
    *) printf '%s\n' "pipx Pipx off" "npm NPM off" "cargo Cargo off";;
  esac
}

v106_install_package_managers(){
  options=$(v106_installable_pm_options)
  [ -n "$options" ] || { ui_msg 'Package Managers' 'No additional package managers are supported for automatic installation on this host.'; return 0; }
  # shellcheck disable=SC2086
  selected=$(ui_checklist 'Install Package Managers' 'Use Space to select multiple items. Compatible selections are installed in one batch. Native managers from other distributions are intentionally excluded.' $options) || return 0
  [ -n "$selected" ] || return 0
  keys=
  for item in $selected; do
    case $item in
      apt-fast) keys="$keys apt-fast";;
      nala) keys="$keys nala";;
      pipx) keys="$keys pipx";;
      flatpak) keys="$keys flatpak";;
      npm) keys="$keys nodejs npm";;
      cargo) keys="$keys rust cargo";;
    esac
  done
  [ -n "$keys" ] && v105_install_keys 'Install package managers' $keys
}

v106_apt_fast_menu(){
  if ! v106_pm_have apt-fast; then
    ui_yesno 'apt-fast' 'apt-fast is not installed. Install it now?' || return 0
    v105_install_keys 'Install apt-fast' apt-fast
    v106_pm_have apt-fast || return 0
  fi
  while :; do
    c=$(ui_menu 'apt-fast Configuration' 'Configure parallel APT downloads. Changes affect the running system only.' \
      edit 'Edit /etc/apt-fast.conf' max 'Set maximum parallel downloads' mirrors 'Edit mirror list' apt 'Configure underlying APT' test 'Test apt-fast update' back 'Back') || return 0
    case $c in
      edit) edit_file /etc/apt-fast.conf;;
      max) n=$(ui_input 'apt-fast' 'Maximum parallel downloads:' '5') || continue; backup_file /etc/apt-fast.conf; if grep -q '^_MAXNUM=' /etc/apt-fast.conf 2>/dev/null; then as_root sed -i "s/^_MAXNUM=.*/_MAXNUM=$n/" /etc/apt-fast.conf; else append_unique /etc/apt-fast.conf "_MAXNUM=$n"; fi;;
      mirrors) edit_file /etc/apt-fast.conf;;
      apt) apt_menu;;
      test) run_capture 'apt-fast update' as_root apt-fast update;;
      back) return 0;;
    esac
  done
}

v106_nala_menu(){
  if ! v106_pm_have nala; then
    ui_yesno 'Nala' 'Nala is not installed. Install it now?' || return 0
    v105_install_keys 'Install Nala' nala
    v106_pm_have nala || return 0
  fi
  while :; do
    c=$(ui_menu 'Nala Configuration' 'APT frontend configuration.' fetch 'Select fastest mirrors' history 'View transaction history' clean 'Clean cache' update 'Refresh indexes' upgrade 'Upgrade packages' back 'Back') || return 0
    case $c in
      fetch) run_capture 'Nala mirror selection' as_root nala fetch;;
      history) run_capture 'Nala history' nala history;;
      clean) run_capture 'Nala clean' as_root nala clean;;
      update) run_capture 'Nala update' as_root nala update;;
      upgrade) run_capture 'Nala upgrade' as_root nala upgrade -y;;
      back) return 0;;
    esac
  done
}

v106_dnf_menu(){
  while :; do
    c=$(ui_menu 'DNF / YUM Configuration' 'Fedora-family package configuration.' config 'Edit dnf.conf' repos 'List repositories' repofiles 'Edit repository files' parallel 'Set parallel downloads' fastest 'Enable fastest mirror' cache 'Clean metadata and cache' back 'Back') || return 0
    case $c in
      config) edit_file /etc/dnf/dnf.conf;;
      repos) run_capture 'DNF repositories' sh -c 'command -v dnf >/dev/null && dnf repolist --all || yum repolist all';;
      repofiles) edit_file /etc/yum.repos.d/ish-aok.repo;;
      parallel) n=$(ui_input 'DNF' 'Maximum parallel downloads:' '5') || continue; append_unique /etc/dnf/dnf.conf "max_parallel_downloads=$n";;
      fastest) append_unique /etc/dnf/dnf.conf 'fastestmirror=True';;
      cache) run_capture 'DNF cache cleanup' as_root sh -c 'command -v dnf >/dev/null && dnf clean all || yum clean all';;
      back) return 0;;
    esac
  done
}

v106_xbps_menu(){
  while :; do
    c=$(ui_menu 'XBPS Configuration' 'Void Linux package configuration.' repos 'Edit repository configuration' list 'List repositories' update 'Synchronize repositories' cache 'Clean cached packages' reconfigure 'Reconfigure installed packages' back 'Back') || return 0
    case $c in
      repos) edit_file /etc/xbps.d/00-repository-main.conf;;
      list) ui_text 'XBPS repositories' "$(grep -Rhs '^repository=' /etc/xbps.d /usr/share/xbps.d 2>/dev/null)";;
      update) run_capture 'XBPS update' as_root xbps-install -S;;
      cache) run_capture 'XBPS cache' as_root xbps-remove -O;;
      reconfigure) run_capture 'XBPS reconfigure' as_root xbps-reconfigure -a;;
      back) return 0;;
    esac
  done
}

v106_portage_menu(){
  while :; do
    c=$(ui_menu 'Portage Configuration' 'Gentoo package configuration.' makeconf 'Edit make.conf' repos 'Edit repos.conf' use 'Edit package.use' keywords 'Edit package.accept_keywords' sync 'Synchronize repositories' world 'Update world set' back 'Back') || return 0
    case $c in
      makeconf) edit_file /etc/portage/make.conf;; repos) edit_file /etc/portage/repos.conf/gentoo.conf;;
      use) edit_file /etc/portage/package.use/ish-aok;; keywords) edit_file /etc/portage/package.accept_keywords/ish-aok;;
      sync) run_capture 'Portage sync' as_root emerge --sync;; world) run_capture 'Portage world update' as_root emerge -avuDN @world;; back) return 0;;
    esac
  done
}

v106_zypper_menu(){
  while :; do
    c=$(ui_menu 'Zypper Configuration' 'openSUSE package configuration.' repos 'List repositories' add 'Add repository' refresh 'Refresh repositories' locks 'List package locks' clean 'Clean caches' back 'Back') || return 0
    case $c in
      repos) run_capture 'Zypper repositories' zypper lr -u;;
      add) url=$(ui_input 'Zypper' 'Repository URL:' '') || continue; name=$(ui_input 'Zypper' 'Repository alias:' 'custom') || continue; run_capture 'Add repository' as_root zypper ar "$url" "$name";;
      refresh) run_capture 'Zypper refresh' as_root zypper refresh;; locks) run_capture 'Zypper locks' zypper locks;; clean) run_capture 'Zypper clean' as_root zypper clean --all;; back) return 0;;
    esac
  done
}

v106_scoop_menu(){
  if ! v106_pm_have scoop; then
    ui_text 'Scoop' 'Scoop is a Windows package manager and cannot manage packages inside an iSH-AOK Linux filesystem.

Use Scoop from Windows PowerShell or Windows Terminal. This menu becomes active only when a compatible scoop command is exposed to the current environment.'
    return 0
  fi
  while :; do
    c=$(ui_menu 'Scoop Configuration' 'External Windows Scoop installation detected.' status 'Show status' buckets 'List buckets' config 'Show configuration' update 'Update Scoop and apps' back 'Back') || return 0
    case $c in status) run_capture 'Scoop status' scoop status;; buckets) run_capture 'Scoop buckets' scoop bucket list;; config) run_capture 'Scoop config' scoop config;; update) run_capture 'Scoop update' scoop update '*';; back) return 0;; esac
  done
}

v106_brew_menu(){
  if ! v106_pm_have brew; then ui_text 'Homebrew' 'Homebrew is not installed. Automatic installation is disabled because its bootstrap process is not suitable for every iSH-AOK filesystem. Install it manually only on a supported environment.'; return 0; fi
  while :; do
    c=$(ui_menu 'Homebrew Configuration' 'Homebrew/Linuxbrew package configuration.' doctor 'Run brew doctor' config 'Show configuration' update 'Update formulas' upgrade 'Upgrade packages' cleanup 'Clean old packages' back 'Back') || return 0
    case $c in doctor) run_capture 'Brew doctor' brew doctor;; config) run_capture 'Brew config' brew config;; update) run_capture 'Brew update' brew update;; upgrade) run_capture 'Brew upgrade' brew upgrade;; cleanup) run_capture 'Brew cleanup' brew cleanup;; back) return 0;; esac
  done
}

v106_language_manager_menu(){
  manager=$1
  case $manager in
    pipx) v106_pm_have pipx || { v105_install_keys 'Install Pipx' pipx; v106_pm_have pipx || return; }; run_capture 'Pipx packages' pipx list;;
    cargo) v106_pm_have cargo || { v105_install_keys 'Install Cargo' rust cargo; v106_pm_have cargo || return; }; run_capture 'Cargo packages' cargo install --list;;
    npm) v106_pm_have npm || { v105_install_keys 'Install NPM' nodejs npm; v106_pm_have npm || return; }; run_capture 'Global NPM packages' npm list -g --depth=0;;
  esac
}

v106_package_managers_menu(){
  while :; do
    c=$(ui_menu 'Package Managers' "Native manager: ${PKG_MGR:-unknown}\nSelect a manager to install or configure it. Unsupported cross-distribution managers are never installed automatically." \
      install 'Install optional package managers (multi-select)' \
      report 'Package manager status report' \
      apt "APT — $(v106_pm_status apt)" \
      aptfast "apt-fast — $(v106_pm_status apt-fast)" \
      nala "Nala — $(v106_pm_status nala)" \
      apk "APK — $(v106_pm_status apk)" \
      pacman "Pacman — $(v106_pm_status pacman)" \
      dnf "DNF / YUM — $(v106_pm_status dnf)" \
      xbps "XBPS — $(v106_pm_status xbps)" \
      portage "Portage — $(v106_pm_status portage)" \
      zypper "Zypper — $(v106_pm_status zypper)" \
      scoop "Scoop — $(v106_pm_status scoop)" \
      brew "Homebrew — $(v106_pm_status brew)" \
      pipx "Pipx — $(v106_pm_status pipx)" \
      cargo "Cargo — $(v106_pm_status cargo)" \
      npm "NPM — $(v106_pm_status npm)" \
      back 'Back') || return 0
    case $c in
      install) v106_install_package_managers;; report) ui_text 'Package Manager Status' "$(v106_pm_report)";;
      apt) v106_pm_have apt-get && apt_menu || ui_msg 'APT' 'APT is not installed and is not native to this system.';;
      aptfast) v106_apt_fast_menu;; nala) v106_nala_menu;;
      apk) v106_pm_have apk && apk_menu || ui_msg 'APK' 'APK is not installed and should only be used on Alpine-compatible systems.';;
      pacman) v106_pm_have pacman && pacman_menu || ui_msg 'Pacman' 'Pacman is not installed and should only be used on Arch-compatible systems.';;
      dnf) { v106_pm_have dnf || v106_pm_have yum; } && v106_dnf_menu || ui_msg 'DNF / YUM' 'DNF/YUM is not installed.';;
      xbps) v106_pm_have xbps-install && v106_xbps_menu || ui_msg 'XBPS' 'XBPS is not installed and should only be used on Void Linux.';;
      portage) v106_pm_have emerge && v106_portage_menu || ui_msg 'Portage' 'Portage is not installed and should only be used on Gentoo.';;
      zypper) v106_pm_have zypper && v106_zypper_menu || ui_msg 'Zypper' 'Zypper is not installed.';;
      scoop) v106_scoop_menu;; brew) v106_brew_menu;; pipx|cargo|npm) v106_language_manager_menu "$c";; back) return 0;;
    esac
  done
}

# Extend v10.5 System Packages while preserving host-only scope isolation.
v106_system_packages_menu(){
  while :; do
    choice=$(ui_menu 'System Packages' 'These actions affect the running iSH-AOK system only.' \
      managers 'Package managers and configuration' \
      quick 'Quick Install: iSH-AOK Essentials' \
      additional 'Install additional packages' \
      groups 'Install curated package groups' \
      manage 'Manage installed packages' \
      remove 'Remove software' \
      search 'Search packages' \
      repositories 'Package repositories' \
      update 'Refresh package indexes' \
      upgrade 'Upgrade installed packages' \
      clean 'Clean package cache' \
      back 'Back') || return 0
    case $choice in
      managers) v106_package_managers_menu;; quick) v105_quick_install;; additional) v105_additional_package;; groups) v105_package_groups_menu;;
      manage) v104_main_scope_call package_menu;;
      remove) p=$(ui_input 'Remove packages' 'Space-separated native package names:' '') || continue; [ -n "$p" ] && v104_main_scope_call pkg_remove $p;;
      search) q=$(ui_input 'Search packages' 'Search term:' '') || continue; [ -n "$q" ] && v104_main_scope_call package_search "$q";;
      repositories) v104_main_scope_call repositories_menu;; update) v104_main_scope_call run_capture 'Package index update' pkg_update;;
      upgrade) v104_main_scope_call run_capture 'System package upgrade' pkg_upgrade;; clean) v104_main_scope_call package_clean;; back) return 0;;
    esac
  done
}

v104_system_packages_menu(){ v104_main_scope_call v106_system_packages_menu; }
