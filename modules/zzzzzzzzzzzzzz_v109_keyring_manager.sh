#!/bin/sh
# v10.9: distribution-aware repository keyring installation and repair.

v109_os_id(){
  if [ -n "${DISTRO_ID:-}" ]; then printf '%s' "$DISTRO_ID"; return; fi
  if [ -r /etc/os-release ]; then . /etc/os-release; printf '%s' "${ID:-unknown}"; else printf unknown; fi
}

v109_keyring_packages(){
  id=$(v109_os_id)
  case ${PKG_MGR:-unknown} in
    apt)
      case $id in
        devuan) printf '%s\n' devuan-keyring debian-archive-keyring;;
        debian) printf '%s\n' debian-archive-keyring;;
        ubuntu) printf '%s\n' ubuntu-keyring;;
        kali) printf '%s\n' kali-archive-keyring;;
        raspbian) printf '%s\n' raspbian-archive-keyring debian-archive-keyring;;
        *) printf '%s\n' debian-archive-keyring;;
      esac
      printf '%s\n' ca-certificates gnupg
      ;;
    apk) printf '%s\n' alpine-keys ca-certificates;;
    pacman) printf '%s\n' archlinux-keyring ca-certificates;;
    dnf|yum)
      case $id in
        fedora) printf '%s\n' fedora-gpg-keys distribution-gpg-keys;;
        centos|rhel|rocky|almalinux) printf '%s\n' distribution-gpg-keys;;
        *) printf '%s\n' distribution-gpg-keys;;
      esac
      printf '%s\n' ca-certificates
      ;;
    xbps) printf '%s\n' void-repo-keyring ca-certificates;;
    emerge) printf '%s\n' app-crypt/gentoo-keys app-misc/ca-certificates;;
    zypper) printf '%s\n' openSUSE-build-key ca-certificates;;
    *) return 1;;
  esac
}

v109_keyring_label(){
  case $1 in
    devuan-keyring) printf 'Devuan archive keyring';;
    debian-archive-keyring) printf 'Debian archive keyring';;
    ubuntu-keyring) printf 'Ubuntu archive keyring';;
    kali-archive-keyring) printf 'Kali archive keyring';;
    raspbian-archive-keyring) printf 'Raspbian archive keyring';;
    alpine-keys) printf 'Alpine repository keys';;
    archlinux-keyring) printf 'Arch Linux keyring';;
    fedora-gpg-keys) printf 'Fedora repository keys';;
    distribution-gpg-keys) printf 'Distribution GPG keys';;
    void-repo-keyring) printf 'Void Linux repository keyring';;
    app-crypt/gentoo-keys) printf 'Gentoo release keys';;
    openSUSE-build-key) printf 'openSUSE build key';;
    ca-certificates) printf 'Certificate authority bundle';;
    app-misc/ca-certificates) printf 'Certificate authority bundle';;
    gnupg) printf 'GNU Privacy Guard tools';;
    *) printf '%s' "$1";;
  esac
}

v109_keyring_checklist(){
  set --
  for p in $(v109_keyring_packages); do
    if v105_pkg_installed "$p"; then state=on; status=Installed
    elif v105_pkg_available "$p"; then state=off; status=Available
    else state=off; status=Unavailable
    fi
    set -- "$@" "$p" "$(v109_keyring_label "$p") — $status [$p]" "$state"
  done
  [ "$#" -gt 0 ] || { ui_msg 'Repository Keyrings' 'No supported keyring package mapping exists for this package manager.'; return 1; }
  ui_checklist 'Install or repair repository keyrings' 'Use Space to select multiple keyring packages. Installed packages start selected so they can also be reinstalled for repair.' "$@"
}

v109_reinstall_packages(){
  [ "$#" -gt 0 ] || return 0
  case ${PKG_MGR:-unknown} in
    apt) _pkg_exec "Reinstalling keyrings: $*" apt-get install --reinstall -y "$@";;
    apk) _pkg_exec "Repairing keyrings: $*" apk fix "$@";;
    pacman) _pkg_exec "Reinstalling keyrings: $*" pacman -S --noconfirm "$@";;
    dnf) _pkg_exec "Reinstalling keyrings: $*" dnf reinstall -y "$@";;
    yum) _pkg_exec "Reinstalling keyrings: $*" yum reinstall -y "$@";;
    xbps) _pkg_exec "Reinstalling keyrings: $*" xbps-install -fy "$@";;
    emerge) _pkg_exec "Reinstalling keyrings: $*" emerge --oneshot "$@";;
    zypper) _pkg_exec "Reinstalling keyrings: $*" zypper --non-interactive install --force-resolution "$@";;
    *) return 1;;
  esac
}

v109_install_missing_keyrings(){
  selected=$(v109_keyring_checklist) || return 0
  [ -n "$selected" ] || return 0
  action=$(ui_menu 'Repository Keyring Action' 'Apply one operation to all selected keyring packages.' install 'Install missing selected keyrings' reinstall 'Reinstall selected keyrings for repair' back Back) || return 0
  [ "$action" = back ] && return 0
  case $action in
    install) v105_install_keys 'Install missing repository keyrings' $selected;;
    reinstall)
      ui_yesno 'Reinstall repository keyrings' "Reinstall these keyring packages in one transaction?\n\n$selected" || return 0
      v109_reinstall_packages $selected
      ;;
  esac
}

v109_apt_signed_by_paths(){
  grep -RhsoE 'signed-by=[^] ,]+' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null \
    | sed 's/^signed-by=//' | sort -u
}

v109_missing_apt_keyring_report(){
  found=0
  out='Missing APT signed-by keyring files:\n'
  for p in $(v109_apt_signed_by_paths); do
    case $p in /*) :;; *) continue;; esac
    if [ ! -s "$p" ]; then out="$out\n- $p"; found=1; fi
  done
  [ "$found" -eq 1 ] || out="$out\n\nNone detected."
  printf '%b\n' "$out"
}

v109_import_local_apt_keyring(){
  [ "${PKG_MGR:-}" = apt ] || { ui_msg 'Import Keyring' 'Local keyring import is currently available for APT systems.'; return 0; }
  src=$(ui_input 'Import local keyring' 'Path to an existing .gpg or .asc key file:' '') || return 0
  [ -f "$src" ] || { ui_msg 'Import Keyring' 'The selected file does not exist.'; return 1; }
  name=$(basename "$src"); case $name in *.asc|*.gpg) :;; *) name="$name.gpg";; esac
  v108_keyring_dir
  dst="/etc/apt/keyrings/$name"
  ui_yesno 'Import Keyring' "Copy this keyring to $dst?\n\nSource: $src" || return 0
  backup_file "$dst"
  as_root cp "$src" "$dst" && as_root chmod 0644 "$dst"
}

v109_native_key_repair(){
  case ${PKG_MGR:-unknown} in
    apt)
      v108_keyring_dir
      v109_install_missing_keyrings
      ;;
    apk)
      v105_install_keys 'Install Alpine repository keys' alpine-keys ca-certificates
      command -v apk >/dev/null 2>&1 && run_capture 'Repair Alpine keys' as_root apk fix alpine-keys
      ;;
    pacman)
      v105_install_keys 'Install Arch Linux keyring' archlinux-keyring ca-certificates
      command -v pacman-key >/dev/null 2>&1 && {
        run_capture 'Initialize Pacman keyring' as_root pacman-key --init
        run_capture 'Populate Pacman keyring' as_root pacman-key --populate
      }
      ;;
    dnf|yum|xbps|emerge|zypper) v109_install_missing_keyrings;;
    *) ui_msg 'Native Key Repair' 'No supported native key repair workflow was detected.';;
  esac
}

v109_list_keyrings(){
  case ${PKG_MGR:-unknown} in
    apt) ui_text 'APT keyrings' "$(find /usr/share/keyrings /etc/apt/keyrings -maxdepth 1 -type f 2>/dev/null | sort)";;
    apk) ui_text 'APK keys' "$(find /etc/apk/keys -maxdepth 1 -type f 2>/dev/null | sort)";;
    pacman) run_capture 'Pacman keys' pacman-key --list-keys;;
    dnf|yum|zypper) ui_text 'RPM repository keys' "$(rpm -qa 'gpg-pubkey*' 2>/dev/null | sort)";;
    xbps) ui_text 'XBPS repository keys' "$(find /var/db/xbps/keys -maxdepth 1 -type f 2>/dev/null | sort)";;
    emerge) ui_text 'Gentoo repository keys' "$(find /var/lib/gentoo/gkeys /usr/share/openpgp-keys -type f 2>/dev/null | sort)";;
    *) ui_msg 'Repository Keyrings' 'No keyring listing method is available for this package manager.';;
  esac
}

v109_repository_keyrings_menu(){
  while :; do
    c=$(ui_menu 'Repository Keyrings' "Native package manager: ${PKG_MGR:-unknown}" \
      install 'Install or reinstall keyring packages (multi-select)' repair 'Run native keyring initialization or repair' missing 'Scan repository definitions for missing keyring files' list 'List installed repository keys and keyrings' import 'Import a local APT keyring file' refresh 'Refresh package indexes after key repair' back Back) || return 0
    case $c in
      install) v109_install_missing_keyrings;;
      repair) v109_native_key_repair;;
      missing)
        if [ "${PKG_MGR:-}" = apt ]; then ui_text 'Missing APT Keyrings' "$(v109_missing_apt_keyring_report)"; else ui_msg 'Missing Keyring Scan' 'Explicit signed-by path scanning applies to APT repository definitions.'; fi
        ;;
      list) v109_list_keyrings;;
      import) v109_import_local_apt_keyring;;
      refresh) run_capture 'Refresh package indexes' pkg_update;;
      back) return 0;;
    esac
  done
}

# Replace the v10.8 repository menu so keyring installation is directly available.
v109_repository_sources_menu(){
  while :; do
    c=$(ui_menu 'Repository & Package Sources' "Native package manager: ${PKG_MGR:-unknown}" \
      native 'Native distribution repositories' apt 'APT sources.list manager' flatpak 'Flatpak and official Flathub remote' keys 'Repository keyrings and missing-key repair' installkeys 'Install missing keyring packages' mirrors 'Mirror and native manager configuration' npm 'NPM registry' pip 'Python package index' cargo 'Cargo registries' health 'Repository health check' backup 'Back up repository configuration' refresh 'Refresh native package indexes' back Back) || return 0
    case $c in
      native|mirrors) v108_native_repository_menu;;
      apt) [ "${PKG_MGR:-}" = apt ] && v108_apt_sources_menu || ui_msg APT 'APT is not the native package manager on this system.';;
      flatpak) v108_flathub_menu;;
      keys) v109_repository_keyrings_menu;;
      installkeys) v109_install_missing_keyrings;;
      npm|pip|cargo) v108_registry_menu "$c";;
      health) v108_repository_health;;
      backup) v108_repository_backup;;
      refresh) run_capture 'Refresh package indexes' pkg_update;;
      back) return 0;;
    esac
  done
}

v108_repository_sources_menu(){ v109_repository_sources_menu; }
