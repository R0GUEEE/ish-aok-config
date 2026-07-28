#!/bin/sh
# v10.8 repository and package-source management for the running iSH-AOK host.
# Uses native repository formats and never writes cross-distribution repositories.

v108_repo_dir(){ [ -d /etc/apt/sources.list.d ] || as_root mkdir -p /etc/apt/sources.list.d; }
v108_keyring_dir(){ [ -d /etc/apt/keyrings ] || as_root mkdir -p /etc/apt/keyrings; }

v108_repo_status(){
  case $1 in
    apt-native) [ -s /etc/apt/sources.list ] || grep -RqsE '^[[:space:]]*deb ' /etc/apt/sources.list.d 2>/dev/null;;
    flathub) command -v flatpak >/dev/null 2>&1 && flatpak remotes --columns=name 2>/dev/null | grep -qx flathub;;
    npm) command -v npm >/dev/null 2>&1;;
    pip) command -v python3 >/dev/null 2>&1;;
    cargo) command -v cargo >/dev/null 2>&1;;
    *) return 1;;
  esac
}

v108_add_apt_source_line(){
  name=$1 default_line=$2
  line=$(ui_input 'Add APT repository' 'Official repository line. Review before saving:' "$default_line") || return 0
  [ -n "$line" ] || return 0
  case $line in deb\ *|deb-src\ *) :;; *) ui_msg 'Invalid repository' 'APT repository lines must begin with deb or deb-src.'; return 1;; esac
  v108_repo_dir
  file="/etc/apt/sources.list.d/$name.list"
  ui_yesno 'Add official repository' "Write this repository to $file?\n\n$line" || return 0
  backup_file "$file"
  printf '%s\n' "$line" | as_root tee "$file" >/dev/null
  run_capture 'Refresh APT package indexes' as_root apt-get update
}

v108_native_apt_defaults(){
  id=${DISTRO_ID:-$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-unknown}")}
  codename=$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_CODENAME:-stable}")
  arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
  case $id in
    devuan) printf 'deb [arch=%s] https://deb.devuan.org/merged %s main contrib non-free non-free-firmware' "$arch" "$codename";;
    debian) printf 'deb [arch=%s] https://deb.debian.org/debian %s main contrib non-free non-free-firmware' "$arch" "$codename";;
    ubuntu) printf 'deb [arch=%s] http://ports.ubuntu.com/ubuntu-ports %s main universe multiverse restricted' "$arch" "$codename";;
    *) printf 'deb https://example.invalid stable main';;
  esac
}

v108_apt_sources_menu(){
  while :; do
    c=$(ui_menu 'APT Sources' 'Manage APT sources for the running system. Dedicated files are preferred over modifying the main sources.list.' \
      native 'Add or replace native official repository' security 'Add security repository' updates 'Add updates repository' editmain 'Edit /etc/apt/sources.list' editdir 'Edit a file in sources.list.d' list 'List active repositories' duplicates 'Find duplicate repository lines' refresh 'Refresh package indexes' back Back) || return 0
    case $c in
      native) line=$(v108_native_apt_defaults); case $line in *example.invalid*) ui_msg 'APT Sources' 'No safe native repository template is available for this distribution.';; *) v108_add_apt_source_line native "$line";; esac;;
      security)
        id=${DISTRO_ID:-}; code=$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_CODENAME:-stable}"); arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
        case $id in
          debian) v108_add_apt_source_line security "deb [arch=$arch] https://security.debian.org/debian-security ${code}-security main contrib non-free non-free-firmware";;
          devuan) v108_add_apt_source_line security "deb [arch=$arch] https://deb.devuan.org/merged ${code}-security main contrib non-free non-free-firmware";;
          ubuntu) v108_add_apt_source_line security "deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports ${code}-security main universe multiverse restricted";;
          *) ui_msg 'Security repository' 'No verified template is available for this distribution.';;
        esac;;
      updates)
        id=${DISTRO_ID:-}; code=$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_CODENAME:-stable}"); arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
        case $id in
          debian) v108_add_apt_source_line updates "deb [arch=$arch] https://deb.debian.org/debian ${code}-updates main contrib non-free non-free-firmware";;
          devuan) v108_add_apt_source_line updates "deb [arch=$arch] https://deb.devuan.org/merged ${code}-updates main contrib non-free non-free-firmware";;
          ubuntu) v108_add_apt_source_line updates "deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports ${code}-updates main universe multiverse restricted";;
          *) ui_msg 'Updates repository' 'No verified template is available for this distribution.';;
        esac;;
      editmain) edit_file /etc/apt/sources.list;;
      editdir) f=$(ui_input 'APT source file' 'Path under /etc/apt/sources.list.d:' 'ish-aok.list') || continue; case $f in */*|..*) ui_msg 'Invalid filename' 'Enter a filename only.';; *) v108_repo_dir; edit_file "/etc/apt/sources.list.d/$f";; esac;;
      list) ui_text 'Active APT repositories' "$(grep -RhsE '^[[:space:]]*deb(-src)? ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)";;
      duplicates) ui_text 'Duplicate APT repositories' "$(grep -RhsE '^[[:space:]]*deb(-src)? ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sed 's/[[:space:]]\+/ /g' | sort | uniq -d)";;
      refresh) run_capture 'APT update' as_root apt-get update;; back) return 0;;
    esac
  done
}

v108_flathub_menu(){
  command -v flatpak >/dev/null 2>&1 || { ui_yesno 'Flatpak' 'Flatpak is not installed. Install it using the native package manager?' && v105_install_keys 'Install Flatpak' flatpak; }
  command -v flatpak >/dev/null 2>&1 || return 0
  while :; do
    status='not configured'; v108_repo_status flathub && status=configured
    c=$(ui_menu 'Flatpak / Flathub' "Official Flathub remote: $status" add 'Add official Flathub remote' remove 'Remove Flathub remote' list 'List Flatpak remotes' update 'Update Flatpak applications' repair 'Repair Flatpak installation' back Back) || return 0
    case $c in
      add) run_capture 'Add Flathub' flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo;;
      remove) ui_yesno 'Remove Flathub' 'Remove the Flathub remote?' && run_capture 'Remove Flathub' flatpak remote-delete flathub;;
      list) run_capture 'Flatpak remotes' flatpak remotes --show-details;; update) run_capture 'Flatpak update' flatpak update -y;; repair) run_capture 'Flatpak repair' flatpak repair --user;; back) return 0;;
    esac
  done
}

v108_registry_menu(){
  mgr=$1
  case $mgr in
    npm)
      command -v npm >/dev/null 2>&1 || { ui_msg NPM 'NPM is not installed.'; return; }
      while :; do c=$(ui_menu 'NPM Registry' 'Configure the Node.js package registry.' show 'Show current registry' official 'Use official npm registry' custom 'Set custom registry' cache 'Show cache location' verify 'Verify cache' back Back) || return; case $c in show) run_capture 'NPM registry' npm config get registry;; official) run_capture 'Set NPM registry' npm config set registry https://registry.npmjs.org/;; custom) u=$(ui_input NPM 'Registry URL:' '') || continue; [ -n "$u" ] && run_capture 'Set NPM registry' npm config set registry "$u";; cache) run_capture 'NPM cache' npm config get cache;; verify) run_capture 'NPM cache verify' npm cache verify;; back) return;; esac; done;;
    pip)
      command -v python3 >/dev/null 2>&1 || { ui_msg Pip 'Python is not installed.'; return; }
      while :; do c=$(ui_menu 'Python Package Index' 'Configure pip package indexes without modifying APT sources.' show 'Show pip configuration' official 'Use official PyPI index' custom 'Set custom index URL' edit 'Edit pip.conf' cache 'Show pip cache' back Back) || return; case $c in show) run_capture 'Pip configuration' python3 -m pip config list;; official) run_capture 'Set PyPI index' python3 -m pip config set global.index-url https://pypi.org/simple;; custom) u=$(ui_input Pip 'Index URL:' '') || continue; [ -n "$u" ] && run_capture 'Set pip index' python3 -m pip config set global.index-url "$u";; edit) mkdir -p "$HOME/.config/pip"; edit_file "$HOME/.config/pip/pip.conf";; cache) run_capture 'Pip cache' python3 -m pip cache dir;; back) return;; esac; done;;
    cargo)
      command -v cargo >/dev/null 2>&1 || { ui_msg Cargo 'Cargo is not installed.'; return; }
      mkdir -p "$HOME/.cargo"
      while :; do c=$(ui_menu 'Cargo Registries' 'Configure Cargo registries. crates.io is used by default.' show 'Show Cargo configuration' sparse 'Use official sparse crates.io protocol' edit 'Edit ~/.cargo/config.toml' list 'List installed Cargo packages' back Back) || return; case $c in show) ui_text 'Cargo configuration' "$(cat "$HOME/.cargo/config.toml" 2>/dev/null || printf 'Default crates.io configuration')";; sparse) printf '%s\n' '[registries.crates-io]' 'protocol = "sparse"' > "$HOME/.cargo/config.toml";; edit) edit_file "$HOME/.cargo/config.toml";; list) run_capture 'Cargo packages' cargo install --list;; back) return;; esac; done;;
  esac
}

v108_native_repository_menu(){
  case ${PKG_MGR:-unknown} in
    apt) v108_apt_sources_menu;;
    apk) apk_menu;; pacman) pacman_menu;; dnf|yum) v106_dnf_menu;; xbps) v106_xbps_menu;; emerge) v106_portage_menu;; zypper) v106_zypper_menu;;
    *) ui_msg 'Native repositories' 'No supported native repository editor was detected.';;
  esac
}

v108_repository_health(){
  out="Repository health check\n\nNative manager: ${PKG_MGR:-unknown}\n"
  case ${PKG_MGR:-unknown} in
    apt)
      active=$(grep -RhsEc '^[[:space:]]*deb ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | awk '{s+=$1} END{print s+0}')
      dup=$(grep -RhsE '^[[:space:]]*deb(-src)? ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sed 's/[[:space:]]\+/ /g' | sort | uniq -d | wc -l | tr -d ' ')
      out="$out\nActive APT entries: $active\nDuplicate entries: $dup\nKeyring directory: $([ -d /etc/apt/keyrings ] && printf present || printf missing)\n"
      ;;
    apk) out="$out\nAPK repository entries: $(grep -cEv '^[[:space:]]*(#|$)' /etc/apk/repositories 2>/dev/null || printf 0)\n";;
    pacman) out="$out\nPacman mirror entries: $(grep -c '^Server' /etc/pacman.d/mirrorlist 2>/dev/null || printf 0)\n";;
    *) out="$out\nUse the native manager menu to inspect configured repositories.\n";;
  esac
  command -v flatpak >/dev/null 2>&1 && out="$out\nFlathub: $(v108_repo_status flathub && printf configured || printf missing)\n"
  ui_text 'Repository Health' "$out"
}

v108_repository_backup(){
  dest=${STATE_DIR:-/var/lib/ish-aok-config}/repository-backups
  stamp=$(date +%Y%m%d-%H%M%S)
  as_root mkdir -p "$dest/$stamp"
  for p in /etc/apt/sources.list /etc/apt/sources.list.d /etc/apt/keyrings /etc/apk/repositories /etc/pacman.conf /etc/pacman.d/mirrorlist /etc/yum.repos.d /etc/xbps.d /etc/portage/repos.conf; do
    [ -e "$p" ] && as_root cp -a "$p" "$dest/$stamp/" 2>/dev/null || true
  done
  ui_msg 'Repository Backup' "Repository configuration copied to:\n$dest/$stamp"
}

v108_repository_sources_menu(){
  while :; do
    c=$(ui_menu 'Repository & Package Sources' 'Manage official native repositories and package registries for the running iSH-AOK system.' \
      native 'Native distribution repositories' apt 'APT sources.list manager' flatpak 'Flatpak and official Flathub remote' keys 'Repository keyrings' mirrors 'Mirror and native manager configuration' npm 'NPM registry' pip 'Python package index' cargo 'Cargo registries' health 'Repository health check' backup 'Back up repository configuration' refresh 'Refresh native package indexes' back Back) || return 0
    case $c in
      native|mirrors) v108_native_repository_menu;;
      apt) [ "${PKG_MGR:-}" = apt ] && v108_apt_sources_menu || ui_msg APT 'APT is not the native package manager on this system.';;
      flatpak) v108_flathub_menu;;
      keys) case ${PKG_MGR:-} in apt) v108_keyring_dir; edit_file /etc/apt/keyrings/README.ish-aok;; pacman) run_capture 'Pacman keys' pacman-key --list-keys;; apk) ui_text 'APK keys' "$(ls -1 /etc/apk/keys 2>/dev/null)";; *) ui_msg 'Repository Keys' 'Use the native package-manager configuration menu for key management.';; esac;;
      npm|pip|cargo) v108_registry_menu "$c";; health) v108_repository_health;; backup) v108_repository_backup;; refresh) run_capture 'Refresh package indexes' pkg_update;; back) return 0;;
    esac
  done
}

# Extend package-manager hub with source configuration.
v108_package_managers_menu(){
  while :; do
    c=$(ui_menu 'Package Managers & Sources' "Native manager: ${PKG_MGR:-unknown}" \
      install 'Install/remove/update optional managers (multi-select)' sources 'Repository and package-source manager' report 'Package manager status report' apt "APT — $(v106_pm_status apt)" aptfast "apt-fast — $(v106_pm_status apt-fast)" nala "Nala — $(v106_pm_status nala)" apk "APK — $(v106_pm_status apk)" pacman "Pacman — $(v106_pm_status pacman)" dnf "DNF / YUM — $(v106_pm_status dnf)" xbps "XBPS — $(v106_pm_status xbps)" portage "Portage — $(v106_pm_status portage)" zypper "Zypper — $(v106_pm_status zypper)" flatpak "Flatpak — $(v106_pm_status flatpak)" scoop "Scoop — $(v106_pm_status scoop)" brew "Homebrew — $(v106_pm_status brew)" pip 'Pip / PyPI source configuration' cargo "Cargo — $(v106_pm_status cargo)" npm "NPM — $(v106_pm_status npm)" back Back) || return 0
    case $c in
      install) v107_manage_group package-managers;; sources) v108_repository_sources_menu;; report) ui_text 'Package Manager Status' "$(v106_pm_report)";;
      apt) v106_pm_have apt-get && apt_menu || ui_msg APT 'APT is not installed.';; aptfast) v106_apt_fast_menu;; nala) v106_nala_menu;; apk) v106_pm_have apk && apk_menu || ui_msg APK 'APK is not installed.';; pacman) v106_pm_have pacman && pacman_menu || ui_msg Pacman 'Pacman is not installed.';; dnf) v106_dnf_menu;; xbps) v106_xbps_menu;; portage) v106_portage_menu;; zypper) v106_zypper_menu;; flatpak) v108_flathub_menu;; scoop) v106_scoop_menu;; brew) v106_brew_menu;; pip) v108_registry_menu pip;; cargo) v108_registry_menu cargo;; npm) v108_registry_menu npm;; back) return 0;;
    esac
  done
}
v106_package_managers_menu(){ v108_package_managers_menu; }

v108_system_packages_menu(){
  while :; do
    choice=$(ui_menu 'System Packages & Sources' 'These actions affect the running iSH-AOK system only.' \
      managers 'Package managers and configuration' sources 'Repository and package-source manager' quick 'Manage iSH-AOK Essentials (multi-select)' additional 'Install additional packages' groups 'Manage curated package groups' manage 'Manage installed packages' search 'Search packages' update 'Refresh package indexes' upgrade 'Upgrade installed packages' clean 'Clean package cache' back Back) || return 0
    case $choice in
      managers) v108_package_managers_menu;; sources) v108_repository_sources_menu;; quick) v107_manage_group essentials;; additional) v105_additional_package;; groups) v105_package_groups_menu;; manage) v104_main_scope_call package_menu;; search) q=$(ui_input 'Search packages' 'Search term:' '') || continue; [ -n "$q" ] && v104_main_scope_call package_search "$q";; update) v104_main_scope_call run_capture 'Package index update' pkg_update;; upgrade) v104_main_scope_call run_capture 'System package upgrade' pkg_upgrade;; clean) v104_main_scope_call package_clean;; back) return 0;;
    esac
  done
}
v104_system_packages_menu(){ v104_main_scope_call v108_system_packages_menu; }
