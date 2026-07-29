#!/bin/bash
###############################################################################
# systui Installation Script
# Installs dependencies and sets up systui as an executable
###############################################################################

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BIN_DIR="$INSTALL_PREFIX/bin"
LIB_DIR="$INSTALL_PREFIX/lib/systui"

###############################################################################
# Colors
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Helper Functions
###############################################################################

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Try: sudo $0"
    fi
}

detect_pm() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v xbps-install >/dev/null 2>&1; then
        echo "xbps"
    elif command -v emerge >/dev/null 2>&1; then
        echo "emerge"
    else
        echo ""
    fi
}

package_is_installed() { # <package-manager> <native-package>
    local pm="$1" pkg="$2"
    case "$pm" in
        apt) dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' ;;
        apk) apk info -e "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        dnf|zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
        xbps) xbps-query -p pkgver "$pkg" >/dev/null 2>&1 ;;
        emerge) has_version "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

install_native_packages() { # <package-manager> <required:0|1> <packages...>
    local pm="$1" required="$2" pkg
    shift 2
    local missing=() failed=()

    for pkg in "$@"; do
        package_is_installed "$pm" "$pkg" || missing+=("$pkg")
    done
    [ ${#missing[@]} -gt 0 ] || return 0

    info "Installing ${#missing[@]} missing package(s): ${missing[*]}"
    case "$pm" in
        apt) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}" ;;
        apk) apk add --no-progress "${missing[@]}" ;;
        pacman) pacman -S --noconfirm --needed "${missing[@]}" ;;
        dnf) dnf install -y "${missing[@]}" ;;
        zypper) zypper --non-interactive install --no-recommends "${missing[@]}" ;;
        xbps) xbps-install -y "${missing[@]}" ;;
        emerge) emerge --noreplace "${missing[@]}" ;;
    esac && return 0

    warn "The package batch was not fully available; retrying one package at a time."
    for pkg in "${missing[@]}"; do
        package_is_installed "$pm" "$pkg" && continue
        case "$pm" in
            apt) DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" ;;
            apk) apk add --no-progress "$pkg" ;;
            pacman) pacman -S --noconfirm --needed "$pkg" ;;
            dnf) dnf install -y "$pkg" ;;
            zypper) zypper --non-interactive install --no-recommends "$pkg" ;;
            xbps) xbps-install -y "$pkg" ;;
            emerge) emerge --noreplace "$pkg" ;;
        esac >/dev/null 2>&1 || failed+=("$pkg")
    done

    if [ ${#failed[@]} -gt 0 ]; then
        if [ "$required" = 1 ]; then
            error "Required dependencies could not be installed: ${failed[*]}"
        fi
        warn "Optional feature dependencies unavailable on this distribution: ${failed[*]}"
    fi
}

install_dependencies() {
    if [ "${SYSTUI_SKIP_DEPS:-0}" = "1" ]; then
        info "Skipping dependency installation (SYSTUI_SKIP_DEPS=1)"
        return 0
    fi

    info "Checking systui and sub-tool dependencies..."

    local pm
    pm=$(detect_pm)
    [ -z "$pm" ] && error "Could not detect package manager. Please install manually."

    # Required packages run the TUI, catalogue synchronization, updater, and
    # archive/provisioning basics. Optional packages unlock rootfs, storage,
    # network diagnostics, source builds, and the managed sub-tools.
    case "$pm" in
        apt)
            info "Detected APT (Debian/Ubuntu/Devuan)."
            apt-get update
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux \
                openssh-client curl wget git ca-certificates openssl \
                man-db tzdata tar gzip xz-utils zstd bzip2 rsync gnupg file \
                procps python3 python3-pip cpio unzip zip jq less sudo iproute2
            install_native_packages "$pm" 0 \
                debootstrap debian-archive-keyring ubuntu-keyring qemu-user-static \
                binfmt-support arch-install-scripts parted fdisk e2fsprogs dosfstools \
                btrfs-progs xfsprogs cryptsetup lvm2 mdadm smartmontools hdparm \
                ethtool dnsmasq iputils-ping dnsutils net-tools nmap traceroute mtr-tiny \
                socat build-essential pkg-config cmake meson ninja-build autoconf \
                automake libtool rustc cargo nodejs npm golang-go flatpak
            ;;
        apk)
            info "Detected APK (Alpine)."
            apk update
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux \
                openssh curl wget git ca-certificates openssl man-db tzdata \
                tar gzip xz zstd bzip2 rsync gnupg file procps \
                python3 py3-pip cpio unzip zip jq less sudo iproute2
            install_native_packages "$pm" 0 \
                qemu-user-static parted e2fsprogs dosfstools btrfs-progs xfsprogs \
                cryptsetup lvm2 mdadm smartmontools hdparm ethtool dnsmasq iputils \
                bind-tools net-tools nmap mtr socat build-base pkgconf cmake meson \
                ninja autoconf automake libtool rust cargo nodejs npm go flatpak
            warn "debootstrap is not normally packaged by Alpine; Debian-family builds use it only when available."
            ;;
        pacman)
            info "Detected pacman (Arch)."
            pacman -Sy --noconfirm
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux \
                openssh curl wget git ca-certificates openssl man-db tzdata \
                tar gzip xz zstd bzip2 rsync gnupg file procps-ng \
                python python-pip cpio unzip zip jq less sudo iproute2
            install_native_packages "$pm" 0 \
                arch-install-scripts qemu-user-static parted e2fsprogs dosfstools \
                btrfs-progs xfsprogs cryptsetup lvm2 mdadm smartmontools hdparm \
                ethtool dnsmasq iputils bind net-tools nmap traceroute mtr socat \
                base-devel pkgconf cmake meson ninja autoconf automake libtool \
                rust nodejs npm go flatpak
            command -v debootstrap >/dev/null 2>&1 || warn "Install debootstrap from the AUR to build Debian-family rootfs images."
            ;;
        dnf)
            info "Detected DNF (Fedora/RHEL)."
            dnf makecache -y
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux \
                openssh-clients curl wget git ca-certificates openssl man-db tzdata \
                tar gzip xz zstd bzip2 rsync gnupg2 file procps-ng \
                python3 python3-pip cpio unzip zip jq less sudo iproute
            install_native_packages "$pm" 0 \
                debootstrap qemu-user-static parted util-linux e2fsprogs dosfstools \
                btrfs-progs xfsprogs cryptsetup lvm2 mdadm smartmontools hdparm \
                ethtool dnsmasq iputils bind-utils net-tools nmap traceroute mtr \
                socat gcc gcc-c++ make pkgconf-pkg-config cmake meson ninja-build \
                autoconf automake libtool rust cargo nodejs npm golang flatpak
            ;;
        zypper)
            info "Detected Zypper (openSUSE/SUSE)."
            zypper --non-interactive refresh
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux openssh \
                curl wget git ca-certificates openssl man man-pages timezone tar \
                gzip xz zstd bzip2 rsync gpg2 file procps python3 python3-pip \
                cpio unzip zip jq less sudo iproute2
            install_native_packages "$pm" 0 \
                qemu-linux-user parted e2fsprogs dosfstools btrfsprogs xfsprogs \
                cryptsetup lvm2 mdadm smartmontools hdparm ethtool dnsmasq iputils \
                bind-utils net-tools nmap traceroute mtr socat gcc gcc-c++ make \
                pkg-config cmake meson ninja autoconf automake libtool rust cargo \
                nodejs npm go flatpak
            ;;
        xbps)
            info "Detected XBPS (Void Linux)."
            xbps-install -S
            install_native_packages "$pm" 1 \
                bash dialog findutils grep sed gawk coreutils util-linux openssh \
                curl wget git ca-certificates openssl man-pages tzdata tar gzip xz \
                zstd bzip2 rsync gnupg2 file procps-ng python3 python3-pip cpio \
                unzip zip jq less sudo iproute2
            install_native_packages "$pm" 0 \
                qemu-user-static parted e2fsprogs dosfstools btrfs-progs xfsprogs \
                cryptsetup lvm2 mdadm smartmontools hdparm ethtool dnsmasq iputils \
                bind-utils net-tools nmap traceroute mtr socat base-devel pkg-config \
                cmake meson ninja autoconf automake libtool rust cargo nodejs npm go \
                flatpak
            ;;
        emerge)
            info "Detected Portage (Gentoo)."
            install_native_packages "$pm" 1 \
                app-shells/bash dev-util/dialog sys-apps/findutils sys-apps/grep \
                sys-apps/sed sys-apps/gawk sys-apps/coreutils sys-apps/util-linux \
                net-misc/openssh net-misc/curl net-misc/wget dev-vcs/git \
                app-misc/ca-certificates dev-libs/openssl sys-apps/man-db \
                sys-libs/timezone-data app-arch/tar app-arch/gzip app-arch/xz-utils \
                app-arch/zstd app-arch/bzip2 net-misc/rsync app-crypt/gnupg \
                sys-apps/file sys-process/procps dev-lang/python app-arch/cpio \
                app-arch/unzip app-arch/zip app-misc/jq sys-apps/less app-admin/sudo
            install_native_packages "$pm" 0 \
                sys-block/parted sys-fs/e2fsprogs sys-fs/dosfstools sys-fs/btrfs-progs \
                sys-fs/xfsprogs sys-fs/cryptsetup sys-fs/lvm2 sys-fs/mdadm \
                sys-apps/smartmontools sys-apps/hdparm sys-apps/ethtool net-dns/dnsmasq \
                net-analyzer/nmap net-analyzer/traceroute net-analyzer/mtr net-misc/socat \
                dev-util/cmake dev-build/meson dev-build/ninja dev-build/autoconf \
                dev-build/automake dev-build/libtool dev-lang/rust dev-lang/nodejs \
                dev-lang/go sys-apps/flatpak
            ;;
    esac

    success "Dependency check complete"
}

check_command() {
    command -v "$1" >/dev/null 2>&1 && return 0 || return 1
}

verify_dependencies() {
    info "Verifying dependencies..."
    
    local missing=""
    for cmd in bash dialog sed awk grep cut tr tar gzip curl; do
        if ! check_command "$cmd"; then
            missing+="$cmd "
        fi
    done
    
    if [ -n "$missing" ]; then
        error "Missing required commands: $missing"
    fi
    
    success "All dependencies present"
}

install_project() {
    info "Installing systui to $LIB_DIR..."
    
    mkdir -p "$LIB_DIR"
    mkdir -p "$BIN_DIR"
    
    # Remove managed content first so files deleted in the new release cannot
    # linger from an older installation. User configuration lives elsewhere.
    rm -rf -- "$LIB_DIR/src" "$LIB_DIR/share" "$LIB_DIR/docs"

    # Copy the latest project files.
    cp -r "$PROJECT_DIR/src" "$LIB_DIR/"
    cp -r "$PROJECT_DIR/share" "$LIB_DIR/"
    [ -d "$PROJECT_DIR/docs" ] && cp -r "$PROJECT_DIR/docs" "$LIB_DIR/" || true
    if [ -f "$PROJECT_DIR/update.sh" ]; then
        install -m 0755 "$PROJECT_DIR/update.sh" "$LIB_DIR/update.sh"
        ln -sfn "$LIB_DIR/update.sh" "$BIN_DIR/systui-update"
    fi

    # Record the source checkout so systui-update works from the installed copy.
    local state_dir="${SYSTUI_STATE_DIR:-/etc/systui}"
    local source_url="" source_branch=""
    mkdir -p "$state_dir"
    if command -v git >/dev/null 2>&1 && git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        source_url=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || true)
        source_branch=$(git -C "$PROJECT_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
        printf '%s\n' "$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)" > "$state_dir/source-dir"
        [ -n "$source_url" ] && printf '%s\n' "$source_url" > "$state_dir/source-url"
        [ -n "$source_branch" ] && printf '%s\n' "$source_branch" > "$state_dir/source-branch"
        chmod 0644 "$state_dir"/source-* 2>/dev/null || true
    fi
    
    success "Project files installed to $LIB_DIR"
}

create_executable() {
    local wrapper_tmp="$BIN_DIR/.systui.$$"
    info "Creating the latest executable wrapper..."

    # Build beside the destination, then replace /usr/local/bin/systui in one
    # operation. This intentionally supersedes any older managed executable.
    rm -f -- "$wrapper_tmp"
    cat > "$wrapper_tmp" << 'WRAPPER'
#!/bin/bash
# systui — Linux System TUI
# Auto-generated by install.sh

LIBDIR="__SYSTUI_LIBDIR__"

# Source core modules
. "$LIBDIR/src/core/config.sh" || exit 1
. "$LIBDIR/src/core/tui-widgets.sh" || exit 1
. "$LIBDIR/src/core/common.sh" || exit 1

# Source provisioning modules
. "$LIBDIR/src/provision/runtime.sh" 2>/dev/null || true
. "$LIBDIR/src/provision/alpine.sh" 2>/dev/null || true
. "$LIBDIR/src/provision/arch.sh" 2>/dev/null || true
. "$LIBDIR/src/provision/debian.sh" 2>/dev/null || true
. "$LIBDIR/src/provision/devuan.sh" 2>/dev/null || true

# Source feature modules (if they exist)
for feature in "$LIBDIR/src/features"/*.sh; do
    [ -f "$feature" ] && . "$feature"
done

# Initialize system detection
detect_pm
detect_init
detect_distro

# Require root for most operations
require_root 2>/dev/null || warn "Some features may require root access"

# Main menu
main_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Main Menu" "systui — choose a section:" \
            provision "Ultimate Provision (provision system)" \
            rootfs    "Rootfs Builder (create minimal systems)" \
            config    "System Configuration" \
            awesome   "Awesome Linux (software catalogue)" \
            health    "System Health (scans and repairs)" \
            quit      "Quit") || return 0
        
        case "$choice" in
            provision)
                menu_ultimate_provision
                ;;
            rootfs)
                menu_rootfs
                ;;
            config)
                menu_sysconfig
                ;;
            awesome)
                menu_awesome_linux
                ;;
            health)
                menu_health
                ;;
            quit)
                return
                ;;
        esac
    done
}

provision_defaults() {
    : "${PROV_TZ:=America/New_York}"
    : "${PROV_LOCALE:=C.UTF-8}"
    : "${PROV_USER:=}"
    : "${PROV_HOST:=}"
    : "${PROV_NOPASS:=0}"
    : "${PROV_SHELL:=bash}"
    : "${PROV_EDITOR:=vim}"
    : "${PROV_PKGS:=core dev terminal network}"
    : "${PROV_SERVICES:=ssh cron timesync logging}"
    : "${PROV_SSH_PORT:=22}"
    : "${PROV_SSH_ROOT:=no}"
    : "${PROV_SSH_PASSWORD:=yes}"
    : "${PROV_FIREWALL:=0}"
    : "${PROV_HARDEN:=0}"
    : "${PROV_PERFORMANCE:=balanced}"
    : "${PROV_SWAP:=0}"
    : "${PROV_CLEAN:=1}"
}

provision_identity_menu() {
    local v
    v=$(tui_input "Timezone" "Timezone (for example UTC or America/New_York)" "$PROV_TZ") || return 0
    [ -n "$v" ] && PROV_TZ="$v"
    v=$(tui_input "Locale" "Locale (for example C.UTF-8 or en_US.UTF-8)" "$PROV_LOCALE") || return 0
    [ -n "$v" ] && PROV_LOCALE="$v"
    v=$(tui_input "Username" "Primary username (empty skips creation)" "$PROV_USER") || return 0
    PROV_USER="$v"
    v=$(tui_input "Hostname" "System hostname (empty keeps current)" "$PROV_HOST") || return 0
    PROV_HOST="$v"
    v=$(tui_radio "Sudo Policy" "Choose sudo authentication policy:" \
        password "Require the user's password" on \
        nopass "Allow passwordless sudo" off) || return 0
    PROV_NOPASS=$([ "$v" = nopass ] && echo 1 || echo 0)
}

provision_shell_menu() {
    local v
    v=$(tui_radio "Default Shell" "Select the default interactive shell:" \
        bash "Bash" $([ "$PROV_SHELL" = bash ] && echo on || echo off) \
        zsh "Zsh" $([ "$PROV_SHELL" = zsh ] && echo on || echo off) \
        fish "Fish" $([ "$PROV_SHELL" = fish ] && echo on || echo off)) || return 0
    PROV_SHELL="$v"
    v=$(tui_radio "Default Editor" "Select the system editor:" \
        nano "Nano" $([ "$PROV_EDITOR" = nano ] && echo on || echo off) \
        vim "Vim" $([ "$PROV_EDITOR" = vim ] && echo on || echo off) \
        neovim "Neovim" $([ "$PROV_EDITOR" = neovim ] && echo on || echo off) \
        micro "Micro" $([ "$PROV_EDITOR" = micro ] && echo on || echo off)) || return 0
    PROV_EDITOR="$v"
}

provision_packages_menu() {
    local v
    v=$(tui_check "Package Profiles" "Select package groups to install:" \
        core "Core administration utilities" on \
        dev "Compilers, Git, Python and build tools" on \
        terminal "TUI tools and terminal productivity" on \
        network "Networking and diagnostics" on \
        server "Web, database and file-sharing clients" off \
        security "Security auditing utilities" off \
        multimedia "FFmpeg, ImageMagick and media tools" off \
        backup "Rsync, rclone, restic and archive tools" off \
        containers "Podman/buildah tools where available" off) || return 0
    PROV_PKGS=$(printf '%s' "$v" | tr -d '"')
}

provision_services_menu() {
    local v
    v=$(tui_check "Services" "Select services to configure and enable:" \
        ssh "OpenSSH server" on \
        cron "Scheduled jobs" on \
        timesync "Chrony or distro time synchronization" on \
        logging "System logging" on \
        avahi "mDNS service discovery" off \
        web "Web server when installed" off) || return 0
    PROV_SERVICES=$(printf '%s' "$v" | tr -d '"')
}

provision_ssh_menu() {
    local v
    v=$(tui_input "SSH Port" "OpenSSH server port" "$PROV_SSH_PORT") || return 0
    case "$v" in ''|*[!0-9]*) ;; *) [ "$v" -ge 1 ] && [ "$v" -le 65535 ] && PROV_SSH_PORT="$v" ;; esac
    v=$(tui_radio "SSH Root Login" "Permit direct root login over SSH:" \
        no "Disable root login" $([ "$PROV_SSH_ROOT" = no ] && echo on || echo off) \
        prohibit-password "Keys only" $([ "$PROV_SSH_ROOT" = prohibit-password ] && echo on || echo off) \
        yes "Allow root login" $([ "$PROV_SSH_ROOT" = yes ] && echo on || echo off)) || return 0
    PROV_SSH_ROOT="$v"
    v=$(tui_radio "SSH Password Login" "Permit password authentication:" \
        yes "Allow passwords" $([ "$PROV_SSH_PASSWORD" = yes ] && echo on || echo off) \
        no "Keys only" $([ "$PROV_SSH_PASSWORD" = no ] && echo on || echo off)) || return 0
    PROV_SSH_PASSWORD="$v"
}

provision_security_menu() {
    local v
    v=$(tui_check "Security" "Select optional security configuration:" \
        firewall "Install and enable a firewall when supported" $([ "$PROV_FIREWALL" = 1 ] && echo on || echo off) \
        harden "Apply conservative SSH and filesystem hardening" $([ "$PROV_HARDEN" = 1 ] && echo on || echo off)) || return 0
    v=$(printf '%s' "$v" | tr -d '"')
    case " $v " in *" firewall "*) PROV_FIREWALL=1 ;; *) PROV_FIREWALL=0 ;; esac
    case " $v " in *" harden "*) PROV_HARDEN=1 ;; *) PROV_HARDEN=0 ;; esac
}

provision_performance_menu() {
    local v
    v=$(tui_radio "Performance Profile" "Choose a conservative system profile:" \
        compatibility "Maximum compatibility for constrained iSH-AOK rootfs" $([ "$PROV_PERFORMANCE" = compatibility ] && echo on || echo off) \
        balanced "Balanced defaults" $([ "$PROV_PERFORMANCE" = balanced ] && echo on || echo off) \
        performance "Higher limits and reduced shell latency" $([ "$PROV_PERFORMANCE" = performance ] && echo on || echo off)) || return 0
    PROV_PERFORMANCE="$v"
    v=$(tui_yesno "Swap" "Create a 512 MiB swap file when supported?") && PROV_SWAP=1 || PROV_SWAP=0
    v=$(tui_yesno "Cleanup" "Remove package caches and unused dependencies after provisioning?") && PROV_CLEAN=1 || PROV_CLEAN=0
}

provision_configure_menu() {
    while true; do
        local c
        c=$(tui_menu "Provision Configuration" "Configure each provisioning area:" \
            identity "Identity, timezone, locale and sudo" \
            shell "Default shell and editor" \
            packages "Package profiles" \
            services "Services and startup" \
            ssh "OpenSSH server settings" \
            security "Firewall and hardening" \
            performance "Performance, swap and cleanup" \
            reset "Reset all provision defaults" \
            back "Back") || return 0
        case "$c" in
            identity) provision_identity_menu ;;
            shell) provision_shell_menu ;;
            packages) provision_packages_menu ;;
            services) provision_services_menu ;;
            ssh) provision_ssh_menu ;;
            security) provision_security_menu ;;
            performance) provision_performance_menu ;;
            reset) unset PROV_TZ PROV_LOCALE PROV_USER PROV_HOST PROV_NOPASS PROV_SHELL PROV_EDITOR PROV_PKGS PROV_SERVICES PROV_SSH_PORT PROV_SSH_ROOT PROV_SSH_PASSWORD PROV_FIREWALL PROV_HARDEN PROV_PERFORMANCE PROV_SWAP PROV_CLEAN; provision_defaults ;;
            back) return 0 ;;
        esac
    done
}

provision_install_extra_packages() {
    local wanted="" group p
    for group in $PROV_PKGS; do
        case "$PM:$group" in
            apt:core) wanted="$wanted acl attr bc dos2unix ethtool" ;;
            apt:dev) wanted="$wanted clang cmake git-lfs shellcheck pkg-config" ;;
            apt:terminal) wanted="$wanted zsh fish micro zoxide" ;;
            apt:network) wanted="$wanted dnsutils whois iperf3 autossh" ;;
            apt:server) wanted="$wanted nginx-light sqlite3 mariadb-client postgresql-client samba-client" ;;
            apt:security) wanted="$wanted lynis clamav aide gnupg" ;;
            apt:multimedia) wanted="$wanted ffmpeg imagemagick sox" ;;
            apt:backup) wanted="$wanted rclone restic borgbackup" ;;
            apt:containers) wanted="$wanted podman buildah skopeo" ;;
            apk:core) wanted="$wanted acl attr bc dos2unix ethtool" ;;
            apk:dev) wanted="$wanted clang git-lfs shellcheck pkgconf" ;;
            apk:terminal) wanted="$wanted zsh fish micro zoxide" ;;
            apk:network) wanted="$wanted whois iperf3 autossh" ;;
            apk:server) wanted="$wanted nginx sqlite mariadb-client postgresql-client samba-client" ;;
            apk:security) wanted="$wanted lynis clamav gnupg" ;;
            apk:multimedia) wanted="$wanted ffmpeg imagemagick sox" ;;
            apk:backup) wanted="$wanted rclone restic borgbackup" ;;
            apk:containers) wanted="$wanted podman buildah skopeo" ;;
            pacman:core) wanted="$wanted acl attr bc dos2unix ethtool" ;;
            pacman:dev) wanted="$wanted clang cmake git-lfs shellcheck pkgconf" ;;
            pacman:terminal) wanted="$wanted zsh fish micro zoxide" ;;
            pacman:network) wanted="$wanted whois iperf3 autossh" ;;
            pacman:server) wanted="$wanted nginx sqlite mariadb-clients postgresql-libs smbclient" ;;
            pacman:security) wanted="$wanted lynis clamav gnupg" ;;
            pacman:multimedia) wanted="$wanted ffmpeg imagemagick sox" ;;
            pacman:backup) wanted="$wanted rclone restic borg" ;;
            pacman:containers) wanted="$wanted podman buildah skopeo" ;;
        esac
    done
    [ -z "$wanted" ] && return 0
    case "$PM" in
        apt) for p in $wanted; do apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 || true; done ;;
        apk) for p in $wanted; do apk add --no-progress "$p" >/dev/null 2>&1 || true; done ;;
        pacman) for p in $wanted; do pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 || true; done ;;
    esac
}

provision_apply_extras() {
    log "Applying Ultimate Provision custom options"
    provision_install_extra_packages

    # Apply the selected locale after the distro base provisioner.
    printf 'LANG=%s\nLC_ALL=%s\n' "$PROV_LOCALE" "$PROV_LOCALE" > /etc/environment
    [ -d /etc/default ] && printf 'LANG=%s\n' "$PROV_LOCALE" > /etc/default/locale
    command -v update-locale >/dev/null 2>&1 && update-locale LANG="$PROV_LOCALE" >/dev/null 2>&1 || true

    local shell_path editor_cmd
    shell_path=$(command -v "$PROV_SHELL" 2>/dev/null || echo /bin/bash)
    case "$PROV_EDITOR" in neovim) editor_cmd=nvim ;; *) editor_cmd="$PROV_EDITOR" ;; esac
    command -v "$editor_cmd" >/dev/null 2>&1 || editor_cmd=vi
    printf 'export EDITOR=%s\nexport VISUAL=%s\n' "$editor_cmd" "$editor_cmd" > /etc/profile.d/20-systui-editor.sh
    chmod 0644 /etc/profile.d/20-systui-editor.sh
    for u in root $PROV_USER; do
        [ -n "$u" ] && id "$u" >/dev/null 2>&1 && usermod -s "$shell_path" "$u" >/dev/null 2>&1 || true
    done

    if [ -f /etc/ssh/sshd_config ]; then
        sed -i -E \
            -e "s/^[#[:space:]]*Port .*/Port $PROV_SSH_PORT/" \
            -e "s/^[#[:space:]]*PermitRootLogin .*/PermitRootLogin $PROV_SSH_ROOT/" \
            -e "s/^[#[:space:]]*PasswordAuthentication .*/PasswordAuthentication $PROV_SSH_PASSWORD/" \
            /etc/ssh/sshd_config
        grep -q '^Port ' /etc/ssh/sshd_config || echo "Port $PROV_SSH_PORT" >> /etc/ssh/sshd_config
        grep -q '^PermitRootLogin ' /etc/ssh/sshd_config || echo "PermitRootLogin $PROV_SSH_ROOT" >> /etc/ssh/sshd_config
        grep -q '^PasswordAuthentication ' /etc/ssh/sshd_config || echo "PasswordAuthentication $PROV_SSH_PASSWORD" >> /etc/ssh/sshd_config
        sshd -t >/dev/null 2>&1 || log "WARN: sshd configuration validation failed"
    fi

    if [ "$PROV_HARDEN" = 1 ]; then
        umask 027
        chmod 700 /root 2>/dev/null || true
        [ -d /etc/ssh ] && chmod 700 /etc/ssh 2>/dev/null || true
        cat > /etc/profile.d/25-systui-security.sh <<'EOF'
umask 027
export HISTCONTROL=ignoreboth:erasedups
EOF
    fi

    # Honor the service selection. Base provisioners may enable defaults first.
    local svc enabled
    for svc in ssh cron timesync logging avahi web; do
        enabled=0
        case " $PROV_SERVICES " in *" $svc "*) enabled=1 ;; esac
        case "$PM:$svc" in
            apt:ssh) names="ssh" ;; apt:cron) names="cron" ;; apt:timesync) names="chrony" ;; apt:logging) names="rsyslog" ;; apt:avahi) names="avahi-daemon" ;; apt:web) names="nginx" ;;
            apk:ssh) names="sshd" ;; apk:cron) names="crond" ;; apk:timesync) names="chronyd" ;; apk:logging) names="syslog-ng" ;; apk:avahi) names="avahi-daemon" ;; apk:web) names="nginx" ;;
            pacman:ssh) names="sshd" ;; pacman:cron) names="cronie" ;; pacman:timesync) names="chronyd" ;; pacman:logging) names="systemd-journald" ;; pacman:avahi) names="avahi-daemon" ;; pacman:web) names="nginx" ;;
            *) names="" ;;
        esac
        [ -n "$names" ] || continue
        if [ "$enabled" = 1 ]; then
            if command -v systemctl >/dev/null 2>&1; then systemctl enable "$names" >/dev/null 2>&1 || true; systemctl restart "$names" >/dev/null 2>&1 || true
            elif command -v rc-update >/dev/null 2>&1; then rc-update add "$names" default >/dev/null 2>&1 || true; rc-service "$names" restart >/dev/null 2>&1 || true
            elif command -v update-rc.d >/dev/null 2>&1; then update-rc.d "$names" enable >/dev/null 2>&1 || true; service "$names" restart >/dev/null 2>&1 || true
            fi
        else
            if command -v systemctl >/dev/null 2>&1; then systemctl disable "$names" >/dev/null 2>&1 || true; systemctl stop "$names" >/dev/null 2>&1 || true
            elif command -v rc-update >/dev/null 2>&1; then rc-update del "$names" default >/dev/null 2>&1 || true; rc-service "$names" stop >/dev/null 2>&1 || true
            elif command -v update-rc.d >/dev/null 2>&1; then update-rc.d "$names" disable >/dev/null 2>&1 || true; service "$names" stop >/dev/null 2>&1 || true
            fi
        fi
    done

    if [ "$PROV_FIREWALL" = 1 ]; then
        case "$PM" in
            apt) apt-get install -y ufw >/dev/null 2>&1 || true; command -v ufw >/dev/null && { ufw allow "$PROV_SSH_PORT/tcp" >/dev/null 2>&1; ufw --force enable >/dev/null 2>&1 || true; } ;;
            apk) apk add --no-progress iptables >/dev/null 2>&1 || true ;;
            pacman) pacman -S --noconfirm --needed ufw >/dev/null 2>&1 || true; command -v ufw >/dev/null && { ufw allow "$PROV_SSH_PORT/tcp" >/dev/null 2>&1; ufw --force enable >/dev/null 2>&1 || true; } ;;
        esac
    fi

    case "$PROV_PERFORMANCE" in
        compatibility) printf 'ulimit -n 1024 2>/dev/null || true\n' > /etc/profile.d/40-systui-performance.sh ;;
        balanced) printf 'ulimit -n 4096 2>/dev/null || true\n' > /etc/profile.d/40-systui-performance.sh ;;
        performance) printf 'ulimit -n 8192 2>/dev/null || true\nexport HISTSIZE=10000 HISTFILESIZE=20000\n' > /etc/profile.d/40-systui-performance.sh ;;
    esac

    if [ "$PROV_SWAP" = 1 ] && [ ! -e /swapfile ] && command -v swapon >/dev/null 2>&1; then
        (fallocate -l 512M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=512 2>/dev/null) && \
            chmod 600 /swapfile && mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile >/dev/null 2>&1 || true
        grep -q '^/swapfile ' /etc/fstab 2>/dev/null || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    if [ "$PROV_CLEAN" = 1 ]; then
        case "$PM" in
            apt) apt-get autoremove -y >/dev/null 2>&1 || true; apt-get clean >/dev/null 2>&1 || true ;;
            apk) rm -rf /var/cache/apk/* 2>/dev/null || true ;;
            pacman) pacman -Sc --noconfirm >/dev/null 2>&1 || true ;;
        esac
    fi
}

provision_write_review() {
    {
        echo "=== ULTIMATE PROVISION - $1 ==="
        echo
        echo "Identity"
        echo "  Timezone: $PROV_TZ"
        echo "  Locale: $PROV_LOCALE"
        echo "  Username: ${PROV_USER:-(unchanged)}"
        echo "  Hostname: ${PROV_HOST:-(unchanged)}"
        echo "  Sudo: $([ "$PROV_NOPASS" = 1 ] && echo passwordless || echo password-required)"
        echo
        echo "Environment"
        echo "  Shell: $PROV_SHELL"
        echo "  Editor: $PROV_EDITOR"
        echo "  Package profiles: ${PROV_PKGS:-none}"
        echo "  Services: ${PROV_SERVICES:-none}"
        echo
        echo "OpenSSH"
        echo "  Port: $PROV_SSH_PORT"
        echo "  Root login: $PROV_SSH_ROOT"
        echo "  Password login: $PROV_SSH_PASSWORD"
        echo
        echo "Security and performance"
        echo "  Firewall: $([ "$PROV_FIREWALL" = 1 ] && echo enabled || echo disabled)"
        echo "  Hardening: $([ "$PROV_HARDEN" = 1 ] && echo enabled || echo disabled)"
        echo "  Profile: $PROV_PERFORMANCE"
        echo "  Swap file: $([ "$PROV_SWAP" = 1 ] && echo 512-MiB || echo disabled)"
        echo "  Cleanup: $([ "$PROV_CLEAN" = 1 ] && echo enabled || echo disabled)"
    } > /tmp/systui.review
}


provision_template_dir() {
    printf '%s\n' "${LIBDIR:-/usr/local/lib/systui}/src/provision"
}

provision_generated_dir() {
    printf '%s\n' "${LIBDIR:-/usr/local/lib/systui}/share/generated-provision"
}

provision_supported_distros() {
    cat <<'EOF'
alpine|Alpine Linux|apk
archlinux|Arch Linux|pacman
debian|Debian|apt
devuan|Devuan|apt
ubuntu|Ubuntu|apt
kali|Kali Linux|apt
fedora|Fedora Linux|dnf
void|Void Linux|xbps
opensuse-leap|openSUSE Leap|zypper
opensuse-tumbleweed|openSUSE Tumbleweed|zypper
gentoo|Gentoo Linux|portage
EOF
}

provision_find_template() {
    local distro="$1" base
    base=$(provision_template_dir)
    for candidate in \
        "$base/$distro-enhanced.sh" \
        "$base/$distro.sh" \
        "$(provision_generated_dir)/provision-$distro.sh"; do
        [ -f "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

provision_templates_menu() {
    local items=() id label pm path status choice
    while IFS='|' read -r id label pm; do
        if path=$(provision_find_template "$id" 2>/dev/null); then
            status="available — $(basename "$path")"
        else
            status="not generated"
        fi
        items+=("$id" "$label ($status)")
    done < <(provision_supported_distros)
    items+=(back "Back")

    while true; do
        choice=$(tui_menu "Provision Templates" "Built-in and generated distribution templates" "${items[@]}") || return 0
        [ "$choice" = back ] && return 0
        if path=$(provision_find_template "$choice" 2>/dev/null); then
            tui_text "Provision Template — $choice" "$path" || true
        else
            tui_msg "Template Missing" "No provision template exists for $choice yet. Use Generate Provision Scripts from the Ultimate Provision menu."
        fi
    done
}

provision_script_body() {
    local distro="$1" label="$2" pm="$3"
    cat <<EOF
#!/bin/bash
# systui standalone adaptive provision script
# Target distribution: $label ($distro)
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
set -Eeuo pipefail

TARGET_DISTRO='$distro'
TARGET_LABEL='$label'
TARGET_PM='$pm'
TIMEZONE=\${TIMEZONE:-America/New_York}
LOCALE=\${LOCALE:-C.UTF-8}
HOSTNAME_VALUE=\${HOSTNAME_VALUE:-systui-$distro}
USERNAME=\${USERNAME:-}
INSTALL_PROFILE=\${INSTALL_PROFILE:-standard}
ENABLE_SSH=\${ENABLE_SSH:-1}

log() { printf '[%s] %s\\n' "\$TARGET_LABEL" "\$*"; }
die() { log "ERROR: \$*" >&2; exit 1; }
need_root() { [ "\$(id -u)" -eq 0 ] || die 'Run this script as root.'; }

analyze_system() {
    OS_ID=unknown OS_LIKE='' OS_NAME=unknown OS_VERSION=unknown
    local file key value
    for file in /etc/os-release /usr/lib/os-release; do
        [ -r "\$file" ] || continue
        while IFS='=' read -r key value; do
            value=\${value#\"}; value=\${value%\"}; value=\${value#\'}; value=\${value%\'}
            case "\$key" in ID) OS_ID=\$value;; ID_LIKE) OS_LIKE=\$value;; PRETTY_NAME) OS_NAME=\$value;; VERSION_ID) OS_VERSION=\$value;; esac
        done < "\$file"
        break
    done
    ARCH=\$(uname -m 2>/dev/null || echo unknown)
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then INIT=systemd
    elif command -v rc-service >/dev/null 2>&1; then INIT=openrc
    elif command -v sv >/dev/null 2>&1; then INIT=runit
    elif command -v update-rc.d >/dev/null 2>&1 || command -v service >/dev/null 2>&1; then INIT=sysvinit
    else INIT=none; fi
    if command -v apt-get >/dev/null 2>&1; then PM=apt
    elif command -v apk >/dev/null 2>&1; then PM=apk
    elif command -v pacman >/dev/null 2>&1; then PM=pacman
    elif command -v dnf >/dev/null 2>&1; then PM=dnf
    elif command -v xbps-install >/dev/null 2>&1; then PM=xbps
    elif command -v zypper >/dev/null 2>&1; then PM=zypper
    elif command -v emerge >/dev/null 2>&1; then PM=portage
    else PM=unknown; fi
    CONTAINER=0; { [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qaE '(docker|containerd|lxc|podman|kubepods)' /proc/1/cgroup 2>/dev/null; } && CONTAINER=1
    log "Detected: \$OS_NAME; id=\$OS_ID; version=\$OS_VERSION; arch=\$ARCH; init=\$INIT; pm=\$PM; container=\$CONTAINER"
}

validate_target() {
    local all=" \$OS_ID \$OS_LIKE " ok=0
    case "\$TARGET_DISTRO" in
        alpine) [[ "\$all" == *' alpine '* ]] && ok=1 ;;
        archlinux) [[ "\$all" == *' arch '* || "\$all" == *' archlinux '* ]] && ok=1 ;;
        debian) [[ "\$all" == *' debian '* ]] && [ "\$OS_ID" != devuan ] && ok=1 ;;
        devuan) [ "\$OS_ID" = devuan ] && ok=1 ;;
        ubuntu|kali) [ "\$OS_ID" = "\$TARGET_DISTRO" ] && ok=1 ;;
        fedora) [[ "\$all" == *' fedora '* || "\$all" == *' rhel '* ]] && ok=1 ;;
        void) [ "\$OS_ID" = void ] && ok=1 ;;
        opensuse-*) [[ "\$all" == *' suse '* || "\$OS_ID" == opensuse* ]] && ok=1 ;;
        gentoo) [ "\$OS_ID" = gentoo ] && ok=1 ;;
    esac
    [ "\$ok" -eq 1 ] || die "Template targets \$TARGET_DISTRO, but this system is \$OS_ID (\${OS_LIKE:-no ID_LIKE})."
    [ "\$PM" = "\$TARGET_PM" ] || die "Expected package manager \$TARGET_PM, detected \$PM."
}

install_packages() {
    case "\$PM" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            case "\$INSTALL_PROFILE" in minimal) pkgs='ca-certificates curl';; developer) pkgs='ca-certificates curl wget git build-essential python3 python3-pip';; server) pkgs='ca-certificates curl openssh-server sudo cron rsyslog';; *) pkgs='ca-certificates curl wget git sudo openssh-server nano vim';; esac
            apt-get install -y --no-install-recommends \$pkgs
            ;;
        apk)
            apk update
            case "\$INSTALL_PROFILE" in minimal) pkgs='ca-certificates curl';; developer) pkgs='ca-certificates curl wget git build-base python3 py3-pip';; server) pkgs='ca-certificates curl openssh sudo dcron';; *) pkgs='ca-certificates curl wget git sudo openssh nano vim';; esac
            apk add --no-progress \$pkgs
            ;;
        pacman) pacman -Syu --noconfirm; pacman -S --needed --noconfirm ca-certificates curl wget git sudo openssh nano vim ;;
        dnf) dnf -y upgrade --refresh; dnf -y install ca-certificates curl wget git sudo openssh-server nano vim-enhanced ;;
        xbps) xbps-install -Suy xbps; xbps-install -y ca-certificates curl wget git sudo openssh nano vim ;;
        zypper) zypper --non-interactive refresh; zypper --non-interactive update; zypper --non-interactive install ca-certificates curl wget git sudo openssh nano vim ;;
        portage) emerge --sync; emerge app-misc/ca-certificates net-misc/curl net-misc/wget dev-vcs/git app-admin/sudo net-misc/openssh app-editors/nano app-editors/vim ;;
        *) die 'Unsupported package manager.' ;;
    esac
}

enable_service() {
    local name="\$1"
    [ "\$CONTAINER" -eq 1 ] && return 0
    case "\$INIT" in
        systemd) systemctl enable "\$name" >/dev/null 2>&1 || true; systemctl restart "\$name" >/dev/null 2>&1 || systemctl start "\$name" >/dev/null 2>&1 || true ;;
        openrc) rc-update add "\$name" default >/dev/null 2>&1 || true; rc-service "\$name" restart >/dev/null 2>&1 || rc-service "\$name" start >/dev/null 2>&1 || true ;;
        runit) [ -d "/etc/sv/\$name" ] && { mkdir -p /var/service; ln -sfn "/etc/sv/\$name" "/var/service/\$name"; }; sv up "\$name" >/dev/null 2>&1 || true ;;
        sysvinit) update-rc.d "\$name" defaults >/dev/null 2>&1 || true; service "\$name" restart >/dev/null 2>&1 || service "\$name" start >/dev/null 2>&1 || true ;;
    esac
}

configure_base() {
    printf '%s\\n' "\$HOSTNAME_VALUE" > /etc/hostname
    [ -e "/usr/share/zoneinfo/\$TIMEZONE" ] && ln -snf "/usr/share/zoneinfo/\$TIMEZONE" /etc/localtime
    [ -f /etc/timezone ] && printf '%s\\n' "\$TIMEZONE" > /etc/timezone
    if [ -n "\$USERNAME" ] && ! id "\$USERNAME" >/dev/null 2>&1; then
        case "\$PM" in apk) adduser -D -s /bin/sh "\$USERNAME";; *) command -v useradd >/dev/null 2>&1 && useradd -m -s /bin/bash "\$USERNAME" || adduser --disabled-password --gecos '' "\$USERNAME";; esac
    fi
    mkdir -p /run/sshd 2>/dev/null || true
    command -v ssh-keygen >/dev/null 2>&1 && ssh-keygen -A 2>/dev/null || true
    if [ "\$ENABLE_SSH" -eq 1 ]; then
        case "\$PM" in apk) enable_service sshd;; *) enable_service sshd; enable_service ssh;; esac
    fi
}

need_root
analyze_system
validate_target
install_packages
configure_base
log 'Provisioning complete'
EOF
    # Remove placeholder escape markers used to protect generated variable expansion.
    sed -i $'s/\\x1b\\\$/\\$/g' /dev/stdout 2>/dev/null || true
}

provision_generate_one() {
    local distro="$1" label="$2" pm="$3" outdir outfile
    outdir=$(provision_generated_dir)
    outfile="$outdir/provision-$distro.sh"
    mkdir -p "$outdir" || return 1
    if [ -e "$outfile" ]; then
        tui_yesno "Existing Script" "A generated script already exists for $label. Overwrite it?" || return 0
    fi
    provision_script_body "$distro" "$label" "$pm" > "$outfile" || return 1
    chmod +x "$outfile"
    log "Generated provision script: $outfile"
}

provision_generate_menu() {
    local opts=() id label pm selected entry generated=0
    while IFS='|' read -r id label pm; do
        if provision_find_template "$id" >/dev/null 2>&1; then
            opts+=("$id" "$label — template exists" off)
        else
            opts+=("$id" "$label — missing" off)
        fi
    done < <(provision_supported_distros)

    selected=$(tui_check "Generate Provision Scripts" \
        "Select distributions. SPACE toggles; generated scripts are stored under $(provision_generated_dir)." \
        "${opts[@]}") || return 0
    [ -n "$selected" ] || return 0

    for id in $selected; do
        id=${id//\"/}
        entry=$(provision_supported_distros | awk -F'|' -v d="$id" '$1==d {print; exit}')
        [ -n "$entry" ] || continue
        IFS='|' read -r id label pm <<< "$entry"
        provision_generate_one "$id" "$label" "$pm" && generated=$((generated + 1))
    done
    tui_msg "Provision Scripts" "Generation completed for $generated selected distribution(s).\n\nDirectory: $(provision_generated_dir)"
}

provision_detect_current() {
    # Return: detected-id|display-name|base-provisioner
    local id="${DISTRO:-unknown}" like="${DISTRO_ID_LIKE:-}" name="${DISTRO_PRETTY_NAME:-${DISTRO:-unknown}}" base=""

    case "$id" in
        alpine) base=alpine ;;
        arch|archlinux) id=archlinux; base=archlinux ;;
        devuan) base=devuan ;;
        debian) base=debian ;;
        ubuntu|linuxmint|pop|neon|elementary|zorin|kali|parrot|raspbian)
            base=debian
            ;;
        artix|manjaro|endeavouros|garuda)
            base=archlinux
            ;;
        *)
            case " $like " in
                *" devuan "*) base=devuan ;;
                *" debian "*|*" ubuntu "*) base=debian ;;
                *" arch "*|*" archlinux "*) base=archlinux ;;
                *" alpine "*) base=alpine ;;
            esac
            ;;
    esac

    printf '%s|%s|%s\n' "$id" "$name" "$base"
}

menu_ultimate_provision() {
    local detected_id distro_name provisioner detection choice rc
    provision_defaults

    # Refresh detection each time the menu opens in case systui is operating
    # inside a newly entered chroot/rootfs.
    detect_pm
    detect_init
    detect_distro
    detection=$(provision_detect_current)
    IFS='|' read -r detected_id distro_name provisioner <<< "$detection"

    if [ -z "$provisioner" ]; then
        tui_msg "Unsupported Distribution" \
            "Detected: $distro_name\nID: $detected_id\nVersion: $DISTRO_VERSION\nID_LIKE: ${DISTRO_ID_LIKE:-none}\nPackage manager: ${PM:-unknown}\n\nUltimate Provision currently has base provisioners for Alpine, Arch-family, Debian-family, and Devuan systems."
        return 0
    fi

    while true; do
        choice=$(tui_menu "Ultimate Provision" \
            "Detected: $distro_name ($detected_id $DISTRO_VERSION) | provisioner: $provisioner | init: ${INIT:-unknown}" \
            review "Review current provisioning plan" \
            configure "Configure all provisioning options" \
            templates "List distribution provision templates" \
            generate "Generate missing distribution provision scripts" \
            run "Run provisioning" \
            info "About Ultimate Provision" \
            back "Back") || return 0
        case "$choice" in
            review) provision_write_review "$distro_name ($detected_id; $provisioner provisioner)"; tui_text "Provision Review" /tmp/systui.review ;;
            configure) provision_configure_menu ;;
            templates) provision_templates_menu ;;
            generate) provision_generate_menu ;;
            run)
                provision_write_review "$distro_name ($detected_id; $provisioner provisioner)"
                tui_text "Final Provision Plan" /tmp/systui.review || true
                tui_yesno "Confirm" "Apply the $provisioner-family provisioning plan to $distro_name?" || continue
                clear
                echo "========== Starting Provision: $distro_name =========="
                echo "Detected ID: $detected_id | Base provisioner: $provisioner | Init: ${INIT:-unknown}"
                rc=0
                case "$provisioner" in
                    alpine) provision_alpine "$PROV_TZ" "$PROV_USER" "$PROV_HOST" "$PROV_NOPASS" || rc=$? ;;
                    debian) provision_debian "$PROV_TZ" "$PROV_USER" "$PROV_HOST" "$PROV_NOPASS" || rc=$? ;;
                    devuan) provision_devuan "$PROV_TZ" "$PROV_USER" "$PROV_HOST" "$PROV_NOPASS" || rc=$? ;;
                    archlinux) provision_arch "$PROV_TZ" "$PROV_USER" "$PROV_HOST" "$PROV_NOPASS" || rc=$? ;;
                esac
                [ "$rc" -eq 0 ] && provision_apply_extras || log "WARN: Base provisioning returned $rc; custom options skipped"
                read -rp "Provisioning finished. Press Enter to return..." _ || true
                ;;
            info)
                cat > /tmp/systui.info <<EOF
ULTIMATE PROVISION

Detected system
  Name: $distro_name
  ID: $detected_id
  Version: $DISTRO_VERSION
  ID_LIKE: ${DISTRO_ID_LIKE:-none}
  Package manager: ${PM:-unknown}
  Init system: ${INIT:-unknown}
  Selected base provisioner: $provisioner

Detection reads /etc/os-release, falls back to /usr/lib/os-release and legacy
release files, and uses ID_LIKE for derivative distributions. Ubuntu, Kali,
Mint, Pop!_OS and similar Debian derivatives use the Debian provisioner;
Manjaro, Artix and similar Arch derivatives use the Arch provisioner.
EOF
                tui_text "About Ultimate Provision" /tmp/systui.info ;;
            back) return 0 ;;
        esac
    done
}

# Run main menu
main_menu
WRAPPER
    sed -i "s|__SYSTUI_LIBDIR__|$LIB_DIR|g" "$wrapper_tmp"
    install -m 0755 "$wrapper_tmp" "$BIN_DIR/systui"
    rm -f -- "$wrapper_tmp"
    success "Executable installed/replaced at $BIN_DIR/systui"
}

create_manpage() {
    info "Creating man page..."
    
    mkdir -p "$INSTALL_PREFIX/share/man/man1"
    
    cat > "$INSTALL_PREFIX/share/man/man1/systui.1" << 'MANPAGE'
.TH SYSTUI 1 "2026-07-29" "systui 1.0.0" "User Commands"
.SH NAME
systui \- Linux System Administration Terminal UI
.SH SYNOPSIS
.B systui
.SH DESCRIPTION
systui is a terminal-based user interface for Linux system configuration,
provisioning, and management.
.SH FEATURES
.IP "•" 2
Ultimate Provision: Comprehensive system setup for Alpine, Arch, Debian, Devuan
.IP "•" 2
System Configuration: Shells, repositories, packages
.IP "•" 2
Dialog-based TUI: Easy navigation and configuration
.SH REQUIREMENTS
.IP "•" 2
Root access (for most operations)
.IP "•" 2
dialog command
.IP "•" 2
Standard Unix tools
.SH USAGE
.B sudo systui
.PP
Navigate using arrow keys and Enter. Press Tab to switch focus.
.SH SEE ALSO
dialog(1), bash(1)
.SH AUTHOR
systui Development Team
MANPAGE
    
    success "Man page created at $INSTALL_PREFIX/share/man/man1/systui.1"
}

cleanup() {
    info "Final checks..."
    
    # Verify installation
    if [ ! -x "$BIN_DIR/systui" ]; then
        error "Failed to create systui executable"
    fi
    
    if ! command -v systui >/dev/null 2>&1; then
        warn "systui not in PATH. Add $BIN_DIR to your PATH:"
        warn "  export PATH=\"$BIN_DIR:\$PATH\""
    fi
    
    success "Installation complete!"
}

###############################################################################
# Main Installation Flow
###############################################################################

main() {
    echo ""
    echo "========== systui Installation =========="
    echo "Version: 1.0.0"
    echo "Install prefix: $INSTALL_PREFIX"
    echo "Library directory: $LIB_DIR"
    echo ""
    
    require_root
    
    info "Step 1: Installing system dependencies..."
    install_dependencies
    
    info "Step 2: Verifying dependencies..."
    verify_dependencies
    
    info "Step 3: Installing project files..."
    install_project
    
    info "Step 4: Creating executable..."
    create_executable
    
    info "Step 5: Creating documentation..."
    create_manpage
    
    cleanup
    
    echo ""
    echo "========== Installation Complete =========="
    echo ""
    echo "To use systui, run:"
    echo "  sudo $BIN_DIR/systui"
    echo ""
    echo "For help, see:"
    echo "  man systui"
    echo ""
}

main "$@"
