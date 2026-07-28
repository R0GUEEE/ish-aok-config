#!/bin/sh
# Distribution integration and capability profiles (v8.4)

V84_STATE_DIR=${V84_STATE_DIR:-$STATE_DIR/distribution-v84}
V84_REPORT_DIR=${V84_REPORT_DIR:-$REPORT_DIR/distribution-v84}
mkdir -p "$V84_STATE_DIR" "$V84_REPORT_DIR" 2>/dev/null || true

v84_root_path(){
  case ${1:-/} in /) printf '/\n';; *) printf '%s\n' "${1%/}";; esac
}

v84_read_os_release(){
  root=$(v84_root_path "${1:-/}")
  file=$root/etc/os-release
  [ -r "$file" ] || file=$root/usr/lib/os-release
  [ -r "$file" ] || return 1
  sed -n 's/^\([A-Z_][A-Z0-9_]*\)=\(.*\)$/\1=\2/p' "$file"
}

v84_os_value(){
  root=$1 key=$2
  v84_read_os_release "$root" 2>/dev/null | sed -n "s/^${key}=//p" | head -n 1 | sed 's/^"//;s/"$//'
}

v84_normalize_distro(){
  id=$(printf '%s' "${1:-unknown}" | tr '[:upper:]' '[:lower:]')
  like=$(printf '%s' "${2:-}" | tr '[:upper:]' '[:lower:]')
  case $id in
    devuan|debian|ubuntu|alpine|arch|archlinux|void|gentoo|fedora|rhel|centos|rocky|almalinux|opensuse*|sles) ;;
    *)
      case " $like " in
        *' devuan '*) id=devuan;;
        *' debian '*) id=debian;;
        *' ubuntu '*) id=ubuntu;;
        *' alpine '*) id=alpine;;
        *' arch '*) id=arch;;
        *' void '*) id=void;;
        *' gentoo '*) id=gentoo;;
        *' fedora '*|*' rhel '*) id=fedora;;
        *' suse '*) id=opensuse;;
      esac
      ;;
  esac
  [ "$id" = archlinux ] && id=arch
  case $id in rhel|centos|rocky|almalinux) id=fedora;; opensuse*|sles) id=opensuse;; esac
  printf '%s\n' "$id"
}

v84_path_has(){ root=$(v84_root_path "$1"); shift; for p in "$@"; do [ -x "$root$p" ] && return 0; done; return 1; }

v84_detect_package_manager(){
  root=$(v84_root_path "${1:-/}")
  v84_path_has "$root" /usr/bin/apt-get /bin/apt-get && { echo apt; return; }
  v84_path_has "$root" /sbin/apk /usr/sbin/apk && { echo apk; return; }
  v84_path_has "$root" /usr/bin/pacman /bin/pacman && { echo pacman; return; }
  v84_path_has "$root" /usr/bin/xbps-install /bin/xbps-install && { echo xbps; return; }
  v84_path_has "$root" /usr/bin/dnf /bin/dnf && { echo dnf; return; }
  v84_path_has "$root" /usr/bin/yum /bin/yum && { echo yum; return; }
  v84_path_has "$root" /usr/bin/emerge /bin/emerge && { echo emerge; return; }
  v84_path_has "$root" /usr/bin/zypper /bin/zypper && { echo zypper; return; }
  echo unknown
}

v84_detect_init(){
  root=$(v84_root_path "${1:-/}")
  [ -x "$root/sbin/openrc" ] || [ -x "$root/bin/openrc" ] || [ -d "$root/etc/runlevels" ] && { echo openrc; return; }
  [ -x "$root/bin/systemctl" ] || [ -x "$root/usr/bin/systemctl" ] || [ -d "$root/etc/systemd/system" ] && { echo systemd; return; }
  [ -x "$root/usr/bin/sv" ] || [ -x "$root/bin/sv" ] || [ -d "$root/etc/sv" ] && { echo runit; return; }
  [ -d "$root/etc/init.d" ] && { echo sysv; return; }
  [ -x "$root/sbin/init" ] && { echo other; return; }
  echo unknown
}

v84_detect_arch(){
  root=$(v84_root_path "${1:-/}")
  [ "$root" = / ] && { uname -m 2>/dev/null || echo unknown; return; }
  for f in "$root/bin/sh" "$root/bin/busybox" "$root/usr/bin/env"; do
    [ -e "$f" ] || continue
    if command -v file >/dev/null 2>&1; then
      desc=$(file -L "$f" 2>/dev/null || true)
      case $desc in *aarch64*|*ARM\ aarch64*) echo aarch64; return;; *ARM*) echo arm; return;; *x86-64*|*x86_64*) echo x86_64; return;; *80386*|*i386*) echo i386; return;; *RISC-V*|*riscv*) echo riscv64; return;; esac
    fi
  done
  echo unknown
}

v84_profile_summary(){
  distro=$1
  case $distro in
    devuan) echo 'APT | SysVinit/OpenRC | debootstrap | Strong iSH-AOK fit';;
    debian) echo 'APT | systemd by default | debootstrap/mmdebstrap | Init conversion may be needed';;
    ubuntu) echo 'APT | systemd by default | debootstrap | Init conversion and service audit recommended';;
    alpine) echo 'APK | OpenRC | apk bootstrap | Excellent minimal RootFS fit';;
    arch) echo 'Pacman | systemd by default | pacstrap | Init replacement required for full boot workflows';;
    void) echo 'XBPS | runit | xbps-install | Good fit with runit support';;
    gentoo) echo 'Portage | OpenRC optional | stage3 | Good fit when OpenRC profile is used';;
    fedora) echo 'DNF | systemd by default | dnf installroot | Init and service compatibility work required';;
    opensuse) echo 'Zypper | systemd by default | zypper/rootfs import | Init conversion may be needed';;
    *) echo 'Unknown profile | Capability detection only';;
  esac
}

v84_bootstrap_methods(){
  case $1 in
    devuan|debian|ubuntu) echo 'debootstrap mmdebstrap';;
    alpine) echo 'apk minirootfs';;
    arch) echo 'pacstrap tarball';;
    void) echo 'xbps-install tarball';;
    gentoo) echo 'stage3';;
    fedora) echo 'dnf-installroot';;
    opensuse) echo 'zypper tarball';;
    *) echo 'custom tarball';;
  esac
}

v84_compatibility_notes(){
  distro=$1 init=$2
  case $init in
    systemd) echo 'warning: systemd is detected; iSH-AOK workflows should use SysVinit, OpenRC, or runit-compatible service handling.';;
    unknown) echo 'warning: no supported init system was detected.';;
    *) echo "ok: init system $init is supported by the service abstraction.";;
  esac
  case $distro in
    arch|fedora|ubuntu|debian|opensuse) [ "$init" = systemd ] && echo 'recommendation: run the init conversion audit before enabling boot services.';;
    alpine) echo 'recommendation: keep OpenRC service scripts and avoid kernel-module-dependent services.';;
    gentoo) echo 'recommendation: use an OpenRC stage3/profile for the least conversion work.';;
    void) echo 'recommendation: verify /var/service links and runit supervision paths.';;
    devuan) echo 'recommendation: use native Devuan repositories and SysVinit service scripts.';;
  esac
  echo 'recommendation: avoid services requiring udev, cgroups, kernel modules, KVM, FUSE, or privileged namespaces unless the host exposes them.'
}

v84_distribution_report_to(){
  root=$(v84_root_path "${1:-/}") out=$2
  id=$(v84_os_value "$root" ID 2>/dev/null || echo unknown)
  like=$(v84_os_value "$root" ID_LIKE 2>/dev/null || true)
  name=$(v84_os_value "$root" PRETTY_NAME 2>/dev/null || echo "$id")
  version=$(v84_os_value "$root" VERSION_ID 2>/dev/null || true)
  distro=$(v84_normalize_distro "$id" "$like")
  pkg=$(v84_detect_package_manager "$root")
  init=$(v84_detect_init "$root")
  arch=$(v84_detect_arch "$root")
  {
    echo "$PROGRAM $VERSION — Distribution Integration"
    echo "Generated: $(date 2>/dev/null || true)"
    echo "Root: $root"
    echo "Name: $name"
    echo "Distribution: $distro"
    echo "Distribution ID: $id"
    echo "ID_LIKE: $like"
    echo "Version: $version"
    echo "Architecture: $arch"
    echo "Package manager: $pkg"
    echo "Init system: $init"
    echo "Bootstrap methods: $(v84_bootstrap_methods "$distro")"
    echo "Profile: $(v84_profile_summary "$distro")"
    echo
    echo '[Capabilities]'
    [ "$pkg" != unknown ] && echo 'package-management=yes' || echo 'package-management=no'
    case $init in sysv|openrc|runit) echo 'native-service-management=yes';; *) echo 'native-service-management=limited';; esac
    [ -x "$root/bin/sh" ] && echo 'posix-shell=yes' || echo 'posix-shell=no'
    [ -r "$root/etc/passwd" ] && echo 'user-database=yes' || echo 'user-database=no'
    [ -r "$root/etc/resolv.conf" ] && echo 'dns-config=yes' || echo 'dns-config=no'
    echo
    echo '[Compatibility]'
    v84_compatibility_notes "$distro" "$init"
  } >"$out"
}

v84_distribution_report(){
  root=${1:-$(active_rootfs 2>/dev/null || echo /)}
  [ -d "$root" ] || root=/
  stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)
  out=$V84_REPORT_DIR/distribution-$stamp.txt
  v84_distribution_report_to "$root" "$out" || return
  printf '%s\n' "$out"
}

v84_profile_table(){
  cat <<'TABLE'
Distribution	Package manager	Preferred init	Bootstrap	iSH-AOK status
Devuan	APT	SysVinit/OpenRC	debootstrap	Recommended
Debian	APT	SysVinit/OpenRC	debootstrap/mmdebstrap	Conversion commonly needed
Ubuntu	APT	SysVinit/OpenRC	debootstrap	Conversion commonly needed
Alpine	APK	OpenRC	apk/minirootfs	Recommended
Arch	Pacman	SysVinit/OpenRC/runit	pacstrap/tarball	Advanced conversion
Void	XBPS	runit	xbps-install	Recommended
Gentoo	Portage	OpenRC	stage3	Recommended with OpenRC
Fedora	DNF	SysVinit/OpenRC	dnf installroot	Advanced conversion
openSUSE	Zypper	SysVinit/OpenRC	zypper/tarball	Advanced conversion
TABLE
}
