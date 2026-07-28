#!/bin/sh
# v10.10.0: cross-distribution RootFS keyrings, multi-select repository additions,
# and reliable terminal editor launching after dialog/whiptail menus.

v110_editor_command(){
  for candidate in "${VISUAL:-}" "${EDITOR:-}" nano nvim vim vi micro; do
    [ -n "$candidate" ] || continue
    cmd=${candidate%% *}
    command -v "$cmd" >/dev/null 2>&1 && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

# Edit a privileged file through a writable temporary copy. This avoids launching
# nano beneath sudo/doas and preserves the controlling terminal after dialog.
edit_file(){
  f=$1
  d=$(dirname "$f")
  need_root || return 1
  [ -d "$d" ] || as_root mkdir -p "$d" || return 1
  [ -e "$f" ] || write_file "$f" 644 '' || return 1
  ed=$(v110_editor_command) || { ui_msg Editor 'No supported editor is installed. Install Nano, Vim, Neovim, or Micro first.'; return 1; }
  backup_file "$f"
  tmp="$TMP_DIR/edit.$$.${f##*/}"
  if [ -r "$f" ]; then cp -p "$f" "$tmp" 2>/dev/null || as_root cat "$f" >"$tmp"; else : >"$tmp"; fi
  chmod u+rw "$tmp" 2>/dev/null || true
  clear 2>/dev/null || printf '\033[2J\033[H'
  printf 'Editing %s with %s\nSave and exit the editor to return to iSH-AOK Config.\n\n' "$f" "$ed"
  # VISUAL/EDITOR may include options, so invoke through sh only for the user-side editor.
  sh -c "$ed \"\$1\"" sh "$tmp"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    if [ -w "$f" ]; then cat "$tmp" >"$f"; else as_root cp "$tmp" "$f"; fi
    rc=$?
  fi
  rm -f "$tmp"
  clear 2>/dev/null || true
  [ "$rc" -eq 0 ] || ui_msg Editor "The editor exited with status $rc. The original file was preserved in the backup directory."
  return 0
}

v110_os_id(){
  root=${1:-/}
  if [ -r "$root/etc/os-release" ]; then
    ( . "$root/etc/os-release"; printf '%s' "${ID:-unknown}" )
  else printf unknown; fi
}

v110_keyring_candidates(){
  case $1 in
    devuan) printf '%s\n' 'devuan-keyring|Devuan archive keyring' 'debian-archive-keyring|Debian archive keyring';;
    debian) printf '%s\n' 'debian-archive-keyring|Debian archive keyring';;
    ubuntu) printf '%s\n' 'ubuntu-keyring|Ubuntu archive keyring';;
    kali) printf '%s\n' 'kali-archive-keyring|Kali archive keyring';;
    raspbian) printf '%s\n' 'raspbian-archive-keyring|Raspbian archive keyring';;
    alpine) printf '%s\n' 'alpine-keys|Alpine repository keys';;
    arch|archlinux) printf '%s\n' 'archlinux-keyring|Arch Linux keyring';;
    fedora) printf '%s\n' 'fedora-gpg-keys|Fedora GPG keys' 'distribution-gpg-keys|Distribution GPG key collection';;
    void) printf '%s\n' 'void-repo-keyring|Void repository keyring';;
    gentoo) printf '%s\n' 'app-crypt/gentoo-keys|Gentoo release keys';;
    opensuse*|suse) printf '%s\n' 'openSUSE-build-key|openSUSE build key';;
  esac
}

v110_keyring_path(){
  case $1 in
    devuan) for f in /usr/share/keyrings/devuan-archive-keyring.gpg /usr/share/keyrings/devuan-keyring.gpg; do [ -s "$f" ] && { echo "$f"; return; }; done;;
    debian) [ -s /usr/share/keyrings/debian-archive-keyring.gpg ] && echo /usr/share/keyrings/debian-archive-keyring.gpg;;
    ubuntu) [ -s /usr/share/keyrings/ubuntu-archive-keyring.gpg ] && echo /usr/share/keyrings/ubuntu-archive-keyring.gpg;;
    kali) [ -s /usr/share/keyrings/kali-archive-keyring.gpg ] && echo /usr/share/keyrings/kali-archive-keyring.gpg;;
    raspbian) [ -s /usr/share/keyrings/raspbian-archive-keyring.gpg ] && echo /usr/share/keyrings/raspbian-archive-keyring.gpg;;
  esac
}

v110_install_builder_keyrings(){
  distro=$1
  entries=$(v110_keyring_candidates "$distro")
  [ -n "$entries" ] || { ui_msg 'Builder keyrings' "No host keyring package mapping is defined for $distro."; return 0; }
  set --
  listfile="$TMP_DIR/v110-keyrings.$$"
  printf '%s\n' "$entries" >"$listfile"
  while IFS='|' read -r pkg label; do
    [ -n "$pkg" ] || continue
    installed=no; v105_pkg_installed "$pkg" && installed=yes
    state=off; [ "$installed" = no ] && state=on
    set -- "$@" "$pkg" "$label — $([ "$installed" = yes ] && printf installed || printf missing)" "$state"
  done <"$listfile"
  rm -f "$listfile"
  selected=$(ui_checklist 'RootFS builder keyrings' "Select missing archive/repository keyrings required to build $distro. Space toggles selections." "$@") || return 0
  [ -n "$selected" ] || return 0
  v105_install_keys "Install $distro builder keyrings" $selected
}

v110_builder_keyring_preflight(){
  distro=$1
  case $distro in devuan|debian|ubuntu|kali|raspbian) :;; *) return 0;; esac
  key=$(v110_keyring_path "$distro")
  [ -n "$key" ] && return 0
  ui_yesno 'Missing builder keyring' "The $distro archive keyring is not installed on the host. Install or repair it before starting the RootFS build?" || return 1
  v110_install_builder_keyrings "$distro"
  key=$(v110_keyring_path "$distro")
  [ -n "$key" ] || {
    ui_msg 'Builder keyring still missing' "The required $distro keyring was not found after package installation. Use Repository Management → Keyrings → Import a keyring file, then retry the build."
    return 1
  }
}

v110_debootstrap_run(){
  distro=$1 suite=$2 arch=$3 dest=$4 mirror=$5 variant=${6:-minbase} includes=${7:-}
  v110_builder_keyring_preflight "$distro" || return 1
  key=$(v110_keyring_path "$distro")
  set -- debootstrap --arch="$arch" --variant="$variant"
  [ -n "$key" ] && set -- "$@" --keyring="$key"
  [ -n "$includes" ] && set -- "$@" --include="$(printf '%s' "$includes" | tr ' ' ',')"
  set -- "$@" "$suite" "$dest"
  [ -n "$mirror" ] && set -- "$@" "$mirror"
  run_capture "Build $distro RootFS" as_root "$@"
}

v110_rootfs_keyrings_menu(){
  selected=$(ui_checklist 'RootFS Builder Keyrings' 'Select distributions whose archive/repository keys should be installed on the host. Space toggles selections.' \
    devuan 'Devuan' off debian 'Debian' off ubuntu 'Ubuntu' off kali 'Kali' off raspbian 'Raspbian' off alpine 'Alpine' off arch 'Arch Linux' off fedora 'Fedora' off void 'Void Linux' off gentoo 'Gentoo' off) || return 0
  [ -n "$selected" ] || return 0
  for distro in $selected; do v110_install_builder_keyrings "$distro"; done
}

v110_apt_additions_menu(){
  id=${DISTRO_ID:-$(v110_os_id /)}
  code=$(. /etc/os-release 2>/dev/null; printf '%s' "${VERSION_CODENAME:-stable}")
  arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
  choices='native Native-off security Security-off updates Updates-off backports Backports-off source Source-packages-off'
  set --
  for token in $choices; do
    case $token in
      *-off) label=${token%-off}; set -- "$@" "$label" off;;
      *) tag=$token;;
    esac
  done
  # Explicit arguments keep POSIX shells and dialog implementations predictable.
  selected=$(ui_checklist 'Add APT Repository Components' 'Space toggles repository additions. Selected entries are reviewed and written together.' \
    native 'Native/base repository' on security 'Security updates' on updates 'Point-release updates' on backports 'Backports' off source 'Source package repositories (deb-src)' off) || return 0
  [ -n "$selected" ] || return 0
  lines=''
  for item in $selected; do
    case "$id:$item" in
      devuan:native) line="deb [arch=$arch] https://deb.devuan.org/merged $code main contrib non-free non-free-firmware";;
      devuan:security) line="deb [arch=$arch] https://deb.devuan.org/merged ${code}-security main contrib non-free non-free-firmware";;
      devuan:updates) line="deb [arch=$arch] https://deb.devuan.org/merged ${code}-updates main contrib non-free non-free-firmware";;
      devuan:backports) line="deb [arch=$arch] https://deb.devuan.org/merged ${code}-backports main contrib non-free non-free-firmware";;
      debian:native) line="deb [arch=$arch] https://deb.debian.org/debian $code main contrib non-free non-free-firmware";;
      debian:security) line="deb [arch=$arch] https://security.debian.org/debian-security ${code}-security main contrib non-free non-free-firmware";;
      debian:updates) line="deb [arch=$arch] https://deb.debian.org/debian ${code}-updates main contrib non-free non-free-firmware";;
      debian:backports) line="deb [arch=$arch] https://deb.debian.org/debian ${code}-backports main contrib non-free non-free-firmware";;
      ubuntu:native) line="deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports $code main universe multiverse restricted";;
      ubuntu:security) line="deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports ${code}-security main universe multiverse restricted";;
      ubuntu:updates) line="deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports ${code}-updates main universe multiverse restricted";;
      ubuntu:backports) line="deb [arch=$arch] http://ports.ubuntu.com/ubuntu-ports ${code}-backports main universe multiverse restricted";;
      *:source) continue;;
      *) continue;;
    esac
    lines="$lines$line\n"
    selected_has "$selected" source && lines="$lines$(printf '%s' "$line" | sed 's/^deb /deb-src /')\n"
  done
  [ -n "$lines" ] || { ui_msg 'APT repositories' 'No supported repository additions were selected for this distribution.'; return 0; }
  file=/etc/apt/sources.list.d/ish-aok-official.list
  ui_yesno 'Add selected repositories' "The following entries will be written together to $file:\n\n$(printf '%b' "$lines")" || return 0
  v108_repo_dir
  write_file "$file" 644 "$lines"
  run_capture 'Refresh APT package indexes' as_root apt-get update
}

# Replace the APT source screen so all official additions are selected in one checklist.
v108_apt_sources_menu(){
  while :; do
    c=$(ui_menu 'APT Sources' 'Manage APT sources for the running system.' add 'Add official repository components (multi-select)' editmain 'Edit /etc/apt/sources.list' editdir 'Edit a file in sources.list.d' list 'List active repositories' duplicates 'Find duplicate repository lines' keys 'Install/repair missing keyrings' refresh 'Refresh package indexes' back Back) || return 0
    case $c in
      add) v110_apt_additions_menu;;
      editmain) edit_file /etc/apt/sources.list;;
      editdir) f=$(ui_input 'APT source file' 'Filename under /etc/apt/sources.list.d:' 'ish-aok.list') || continue; case $f in */*|..*) ui_msg 'Invalid filename' 'Enter a filename only.';; *) v108_repo_dir; edit_file "/etc/apt/sources.list.d/$f";; esac;;
      list) ui_text 'Active APT repositories' "$(grep -RhsE '^[[:space:]]*deb(-src)? ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)";;
      duplicates) ui_text 'Duplicate APT repositories' "$(grep -RhsE '^[[:space:]]*deb(-src)? ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sed 's/[[:space:]]\+/ /g' | sort | uniq -d)";;
      keys) v109_repository_keyrings_menu;; refresh) run_capture 'APT update' as_root apt-get update;; back) return 0;;
    esac
  done
}

# Expose builder key preparation from the repository center and builder menus.
v108_repository_sources_menu(){
  while :; do
    c=$(ui_menu 'Repository & Package Sources' 'Manage official repositories, registries, mirrors, and build keyrings.' native 'Native distribution repositories' apt 'APT sources manager' additions 'Add native repository components (multi-select)' builderkeys 'Install keys for RootFS target distributions' flatpak 'Flatpak and Flathub' keys 'Repository keyrings and missing-key repair' mirrors 'Mirror and native manager configuration' npm 'NPM registry' pip 'Python package index' cargo 'Cargo registries' health 'Repository health check' backup 'Back up repository configuration' refresh 'Refresh native package indexes' back Back) || return 0
    case $c in
      native|mirrors) v108_native_repository_menu;; apt) [ "${PKG_MGR:-}" = apt ] && v108_apt_sources_menu || ui_msg APT 'APT is not the native package manager on this system.';; additions) case ${PKG_MGR:-} in apt) v110_apt_additions_menu;; apk) apk_menu;; pacman) pacman_menu;; dnf|yum) v106_dnf_menu;; xbps) v106_xbps_menu;; emerge) v106_portage_menu;; *) ui_msg Repositories 'No safe multi-select repository additions are defined for this native manager.';; esac;; builderkeys) v110_rootfs_keyrings_menu;; flatpak) v108_flathub_menu;; keys) v109_repository_keyrings_menu;; npm|pip|cargo) v108_registry_menu "$c";; health) v108_repository_health;; backup) v108_repository_backup;; refresh) run_capture 'Refresh package indexes' pkg_update;; back) return 0;;
    esac
  done
}

# Override the classic portable builder with keyring-aware Debian-family builds.
rootfs_builder_menu(){
  while :; do
    c=$(ui_menu 'RootFS builder and manager' 'Portable RootFS workflows with cross-distribution keyring preparation.' discover 'Discover root filesystems' debian 'Build Debian RootFS' devuan 'Build Devuan RootFS' ubuntu 'Build Ubuntu RootFS' keyrings 'Install target-distribution keyrings' alpine 'Build Alpine RootFS' arch 'Build Arch RootFS' validate 'Validate selected RootFS' mount 'Generate mount/chroot helper' archive 'Archive selected RootFS' clone 'Clone RootFS' packages 'Inventory RootFS packages' config 'Copy host network configuration into RootFS' back Back) || return 0
    case $c in
      discover) run_capture RootFS sh -c 'find /root /AOK /opt/AOK -maxdepth 4 -type f -name os-release -print 2>/dev/null';;
      debian|devuan|ubuntu)
        ensure_tool debootstrap debootstrap || continue
        case $c in debian) suite_default=trixie; mirror_default=https://deb.debian.org/debian;; devuan) suite_default=excalibur; mirror_default=https://deb.devuan.org/merged;; ubuntu) suite_default=noble; mirror_default=http://ports.ubuntu.com/ubuntu-ports;; esac
        suite=$(ui_input RootFS 'Release/suite:' "$suite_default") || continue
        arch=$(ui_input RootFS 'Architecture:' arm64) || continue
        dest=$(ui_input RootFS 'Destination:' "/root/$c-$suite-$arch") || continue
        mirror=$(ui_input RootFS 'Official mirror URL:' "$mirror_default") || continue
        v110_debootstrap_run "$c" "$suite" "$arch" "$dest" "$mirror" minbase '';;
      keyrings) v110_rootfs_keyrings_menu;;
      alpine) v=$(ui_input Alpine 'Version branch' v3.22) || continue; arch=$(ui_input Alpine 'Architecture' aarch64) || continue; dest=$(ui_input Alpine 'Destination' "/root/alpine-$arch") || continue; v110_builder_keyring_preflight alpine || true; mkdir -p "$dest"; run_capture Alpine as_root apk --root "$dest" --arch "$arch" --initdb add alpine-base;;
      arch) v110_builder_keyring_preflight arch || true; ui_msg Arch 'Use pacstrap or pacman --root when available. The Arch keyring preparation option is available from this menu.';;
      validate) r=$(ui_input Validate 'RootFS path' /root/rootfs) || continue; run_capture Validate sh -c "test -f '$r/etc/os-release'; test -x '$r/bin/sh'; file '$r/bin/sh'";;
      mount) r=$(ui_input Helper 'RootFS path' /root/rootfs) || continue; out="$CURRENT_HOME/bin/chroot-$(basename "$r")"; mkdir -p "$CURRENT_HOME/bin"; write_file "$out" 755 "#!/bin/sh\nROOT='$r'\nmount --rbind /dev \"\$ROOT/dev\"\nmount -t proc proc \"\$ROOT/proc\"\nmount --rbind /sys \"\$ROOT/sys\"\nmkdir -p \"\$ROOT/run\"\nmount --bind /run \"\$ROOT/run\"\nchroot \"\$ROOT\" /bin/sh"; ui_msg Helper "Created $out";;
      archive) r=$(ui_input Archive 'RootFS path' /root/rootfs) || continue; o=$(ui_input Archive 'Output' rootfs.tar.zst) || continue; run_capture Archive sh -c "tar -C '$r' -cf - . | zstd -T0 -o '$o'";;
      clone) r=$(ui_input Clone 'Source RootFS' /root/rootfs) || continue; d=$(ui_input Clone 'Destination' /root/rootfs-copy) || continue; run_capture Clone cp -a "$r" "$d";;
      packages) r=$(ui_input Inventory 'RootFS path' /root/rootfs) || continue; if [ -f "$r/var/lib/dpkg/status" ]; then awk '/^Package:|^Version:/{printf "%s ", $2} /^Version:/{print ""}' "$r/var/lib/dpkg/status" >"$TMP_DIR/rpkgs"; elif [ -f "$r/lib/apk/db/installed" ]; then awk '/^P:|^V:/{printf "%s ",substr($0,3)} /^V:/{print ""}' "$r/lib/apk/db/installed" >"$TMP_DIR/rpkgs"; fi; ui_text Packages "$(cat "$TMP_DIR/rpkgs" 2>/dev/null)";;
      config) r=$(ui_input Copy 'RootFS path' /root/rootfs) || continue; cp -L /etc/resolv.conf "$r/etc/resolv.conf" 2>/dev/null; cp /etc/hosts "$r/etc/hosts" 2>/dev/null; ui_msg Copy 'Copied resolv.conf and hosts.';; back) return 0;;
    esac
  done
}
