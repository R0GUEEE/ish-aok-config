#!/bin/sh
# iSH-AOK Config installer and dependency scanner.
set -eu

PREFIX=${PREFIX:-/usr/local}
DEST=${DESTDIR:-}$PREFIX/lib/ish-aok-config
BINDIR=${DESTDIR:-}$PREFIX/bin
SELF=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

DRY_RUN=0
CHECK_ONLY=0
SKIP_DEPS=${ISH_AOK_SKIP_DEPENDENCIES:-0}
ASSUME_YES=${ISH_AOK_ASSUME_YES:-1}
WITH_BUILDERS=${ISH_AOK_INSTALL_BUILDERS:-0}
PM=''
OS_ID='unknown'
OS_LIKE=''
MISSING=''
PACKAGES=''
AVAILABLE_PACKAGES=''
SKIPPED_PACKAGES=''

usage() {
    cat <<'USAGE'
Usage: ./install.sh [options]

Scans the current system, installs missing runtime dependencies, and installs
ish-aok-config.

Options:
  --check             Report missing dependencies without installing anything
  --dry-run           Show package-manager and file-install commands
  --skip-deps         Do not scan or install packages
  --with-builders     Also install available native RootFS builder utilities
  --interactive       Let the package manager ask for confirmation
  --prefix PATH       Installation prefix (default: /usr/local)
  -h, --help          Show this help

Environment overrides:
  PREFIX, DESTDIR, ISH_AOK_SKIP_DEPENDENCIES,
  ISH_AOK_ASSUME_YES, ISH_AOK_INSTALL_BUILDERS
USAGE
}

say() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

append_word() {
    _aw_var=$1 _aw_word=$2
    eval "_aw_current=\${$_aw_var:-}"
    case " $_aw_current " in
        *" $_aw_word "*) return 0 ;;
    esac
    if [ -n "$_aw_current" ]; then
        eval "$_aw_var=\$_aw_current\ \$_aw_word"
    else
        eval "$_aw_var=\$_aw_word"
    fi
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '+ '
        printf '%s ' "$@"
        printf '\n'
        return 0
    fi
    "$@"
}

as_root() {
    if [ "$(id -u 2>/dev/null || printf 1)" -eq 0 ]; then
        run "$@"
    elif have doas; then
        run doas "$@"
    elif have sudo; then
        run sudo "$@"
    else
        warn "Root privileges are required to install packages or files."
        return 1
    fi
}

detect_system() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID=${ID:-unknown}
        OS_LIKE=${ID_LIKE:-}
    fi

    if have apt-get; then PM=apt
    elif have apk; then PM=apk
    elif have pacman; then PM=pacman
    elif have dnf; then PM=dnf
    elif have xbps-install; then PM=xbps
    elif have emerge; then PM=emerge
    else PM=unknown
    fi
}

package_for() {
    _pf_feature=$1
    case "$PM:$_pf_feature" in
        apt:dialog) printf '%s' dialog ;;
        apt:coreutils) printf '%s' coreutils ;;
        apt:findutils) printf '%s' findutils ;;
        apt:grep) printf '%s' grep ;;
        apt:sed) printf '%s' sed ;;
        apt:awk) printf '%s' gawk ;;
        apt:tar) printf '%s' tar ;;
        apt:gzip) printf '%s' gzip ;;
        apt:xz) printf '%s' xz-utils ;;
        apt:util-linux) printf '%s' util-linux ;;
        apt:rsync) printf '%s' rsync ;;
        apt:curl) printf '%s' curl ;;
        apt:certs) printf '%s' ca-certificates ;;
        apt:openssl) printf '%s' openssl ;;
        apt:procps) printf '%s' procps ;;
        apt:file) printf '%s' file ;;
        apt:git) printf '%s' git ;;
        apt:debootstrap) printf '%s' debootstrap ;;

        apk:dialog) printf '%s' dialog ;;
        apk:coreutils) printf '%s' coreutils ;;
        apk:findutils) printf '%s' findutils ;;
        apk:grep) printf '%s' grep ;;
        apk:sed) printf '%s' sed ;;
        apk:awk) printf '%s' gawk ;;
        apk:tar) printf '%s' tar ;;
        apk:gzip) printf '%s' gzip ;;
        apk:xz) printf '%s' xz ;;
        apk:util-linux) printf '%s' util-linux ;;
        apk:rsync) printf '%s' rsync ;;
        apk:curl) printf '%s' curl ;;
        apk:certs) printf '%s' ca-certificates ;;
        apk:openssl) printf '%s' openssl ;;
        apk:procps) printf '%s' procps ;;
        apk:file) printf '%s' file ;;
        apk:git) printf '%s' git ;;

        pacman:dialog) printf '%s' dialog ;;
        pacman:coreutils) printf '%s' coreutils ;;
        pacman:findutils) printf '%s' findutils ;;
        pacman:grep) printf '%s' grep ;;
        pacman:sed) printf '%s' sed ;;
        pacman:awk) printf '%s' gawk ;;
        pacman:tar) printf '%s' tar ;;
        pacman:gzip) printf '%s' gzip ;;
        pacman:xz) printf '%s' xz ;;
        pacman:util-linux) printf '%s' util-linux ;;
        pacman:rsync) printf '%s' rsync ;;
        pacman:curl) printf '%s' curl ;;
        pacman:certs) printf '%s' ca-certificates ;;
        pacman:openssl) printf '%s' openssl ;;
        pacman:procps) printf '%s' procps-ng ;;
        pacman:file) printf '%s' file ;;
        pacman:git) printf '%s' git ;;
        pacman:pacstrap) printf '%s' arch-install-scripts ;;

        dnf:dialog) printf '%s' dialog ;;
        dnf:coreutils) printf '%s' coreutils ;;
        dnf:findutils) printf '%s' findutils ;;
        dnf:grep) printf '%s' grep ;;
        dnf:sed) printf '%s' sed ;;
        dnf:awk) printf '%s' gawk ;;
        dnf:tar) printf '%s' tar ;;
        dnf:gzip) printf '%s' gzip ;;
        dnf:xz) printf '%s' xz ;;
        dnf:util-linux) printf '%s' util-linux ;;
        dnf:rsync) printf '%s' rsync ;;
        dnf:curl) printf '%s' curl ;;
        dnf:certs) printf '%s' ca-certificates ;;
        dnf:openssl) printf '%s' openssl ;;
        dnf:procps) printf '%s' procps-ng ;;
        dnf:file) printf '%s' file ;;
        dnf:git) printf '%s' git ;;
        dnf:dnf) printf '%s' dnf ;;

        xbps:dialog) printf '%s' dialog ;;
        xbps:coreutils) printf '%s' coreutils ;;
        xbps:findutils) printf '%s' findutils ;;
        xbps:grep) printf '%s' grep ;;
        xbps:sed) printf '%s' sed ;;
        xbps:awk) printf '%s' gawk ;;
        xbps:tar) printf '%s' tar ;;
        xbps:gzip) printf '%s' gzip ;;
        xbps:xz) printf '%s' xz ;;
        xbps:util-linux) printf '%s' util-linux ;;
        xbps:rsync) printf '%s' rsync ;;
        xbps:curl) printf '%s' curl ;;
        xbps:certs) printf '%s' ca-certificates ;;
        xbps:openssl) printf '%s' openssl ;;
        xbps:procps) printf '%s' procps-ng ;;
        xbps:file) printf '%s' file ;;
        xbps:git) printf '%s' git ;;

        emerge:dialog) printf '%s' app-misc/dialog ;;
        emerge:coreutils) printf '%s' sys-apps/coreutils ;;
        emerge:findutils) printf '%s' sys-apps/findutils ;;
        emerge:grep) printf '%s' sys-apps/grep ;;
        emerge:sed) printf '%s' sys-apps/sed ;;
        emerge:awk) printf '%s' sys-apps/gawk ;;
        emerge:tar) printf '%s' app-arch/tar ;;
        emerge:gzip) printf '%s' app-arch/gzip ;;
        emerge:xz) printf '%s' app-arch/xz-utils ;;
        emerge:util-linux) printf '%s' sys-apps/util-linux ;;
        emerge:rsync) printf '%s' net-misc/rsync ;;
        emerge:curl) printf '%s' net-misc/curl ;;
        emerge:certs) printf '%s' app-misc/ca-certificates ;;
        emerge:openssl) printf '%s' dev-libs/openssl ;;
        emerge:procps) printf '%s' sys-process/procps ;;
        emerge:file) printf '%s' sys-apps/file ;;
        emerge:git) printf '%s' dev-vcs/git ;;
        *) return 1 ;;
    esac
}

need_feature() {
    _nf_feature=$1
    shift
    _nf_found=0
    for _nf_cmd in "$@"; do
        if have "$_nf_cmd"; then _nf_found=1; break; fi
    done
    [ "$_nf_found" -eq 1 ] && return 0

    append_word MISSING "$_nf_feature"
    _nf_pkg=$(package_for "$_nf_feature" 2>/dev/null || true)
    [ -n "$_nf_pkg" ] && append_word PACKAGES "$_nf_pkg"
}

scan_dependencies() {
    MISSING=''
    PACKAGES=''
AVAILABLE_PACKAGES=''
SKIPPED_PACKAGES=''

    # Required by the menu engine and common RootFS operations.
    need_feature dialog dialog whiptail
    need_feature coreutils mktemp sort cut tr head tail wc id date readlink sha256sum
    need_feature findutils find xargs
    need_feature grep grep
    need_feature sed sed
    need_feature awk awk
    need_feature tar tar
    need_feature gzip gzip
    need_feature xz xz
    need_feature util-linux mount umount chroot
    need_feature rsync rsync
    need_feature curl curl wget
    need_feature certs update-ca-certificates
    need_feature openssl openssl
    need_feature procps ps
    need_feature file file
    need_feature git git

    if [ "$WITH_BUILDERS" -eq 1 ]; then
        case "$PM" in
            apt) need_feature debootstrap debootstrap ;;
            apk) : ;; # apk itself is the native builder
            pacman) need_feature pacstrap pacstrap ;;
            dnf) need_feature dnf dnf ;;
            xbps) : ;; # xbps-install itself is the native builder
        esac
    fi
}

print_scan() {
    say "System scan"
    say "  Distribution: $OS_ID${OS_LIKE:+ ($OS_LIKE)}"
    say "  Architecture: $(uname -m 2>/dev/null || printf unknown)"
    say "  Package manager: $PM"
    if [ -n "$MISSING" ]; then
        say "  Missing features: $MISSING"
        if [ -n "$PACKAGES" ]; then
            say "  Packages to install: $PACKAGES"
        else
            warn "No package mapping is available for this package manager."
        fi
    else
        say "  Dependencies: satisfied"
    fi
}

package_available() {
    _pa_pkg=$1
    case "$PM" in
        apt) apt-cache show "$_pa_pkg" >/dev/null 2>&1 ;;
        apk) apk search -e "$_pa_pkg" 2>/dev/null | grep -q . ;;
        pacman) pacman -Si "$_pa_pkg" >/dev/null 2>&1 ;;
        dnf)
            if have repoquery; then repoquery "$_pa_pkg" >/dev/null 2>&1
            else dnf -q list --available "$_pa_pkg" >/dev/null 2>&1 || dnf -q list --installed "$_pa_pkg" >/dev/null 2>&1
            fi
            ;;
        xbps) xbps-query -Rs "^${_pa_pkg}-[0-9]" 2>/dev/null | grep -q . ;;
        emerge) emerge --search "$_pa_pkg" 2>/dev/null | grep -q '^\*' ;;
        *) return 1 ;;
    esac
}

filter_available_packages() {
    AVAILABLE_PACKAGES=''
    SKIPPED_PACKAGES=''
    for _fa_pkg in $PACKAGES; do
        if package_available "$_fa_pkg"; then
            append_word AVAILABLE_PACKAGES "$_fa_pkg"
        else
            append_word SKIPPED_PACKAGES "$_fa_pkg"
            warn "Package not found in enabled repositories; skipping: $_fa_pkg"
        fi
    done
}

install_packages() {
    [ -z "$PACKAGES" ] && return 0
    [ "$PM" != unknown ] || { warn "No supported package manager was found; continuing without dependency installation."; return 0; }

    say "Checking enabled repositories for dependency packages..."
    case "$PM" in
        apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get update || warn "Package index update failed; using currently available metadata." ;;
        apk) as_root apk update || warn "Package index update failed; using currently available metadata." ;;
        pacman) as_root pacman -Sy --noconfirm || warn "Package index update failed; using currently available metadata." ;;
        dnf) as_root dnf -q makecache || warn "Package index update failed; using currently available metadata." ;;
        xbps) as_root xbps-install -S || warn "Package index update failed; using currently available metadata." ;;
        emerge) as_root emerge --sync || warn "Repository sync failed; using currently available metadata." ;;
    esac

    filter_available_packages
    [ -n "$AVAILABLE_PACKAGES" ] || {
        warn "None of the mapped dependency packages are available; continuing with the tool installation."
        return 0
    }

    say "Installing available dependencies: $AVAILABLE_PACKAGES"
    [ -z "$SKIPPED_PACKAGES" ] || say "Skipped unavailable packages: $SKIPPED_PACKAGES"
    case "$PM" in
        apt)
            if [ "$ASSUME_YES" -eq 1 ]; then
                # shellcheck disable=SC2086
                as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            else
                # shellcheck disable=SC2086
                as_root apt-get install $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            fi
            ;;
        apk)
            # shellcheck disable=SC2086
            as_root apk add $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            ;;
        pacman)
            if [ "$ASSUME_YES" -eq 1 ]; then
                # shellcheck disable=SC2086
                as_root pacman -S --needed --noconfirm $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            else
                # shellcheck disable=SC2086
                as_root pacman -S --needed $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            fi
            ;;
        dnf)
            if [ "$ASSUME_YES" -eq 1 ]; then
                # shellcheck disable=SC2086
                as_root dnf install -y $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            else
                # shellcheck disable=SC2086
                as_root dnf install $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            fi
            ;;
        xbps)
            if [ "$ASSUME_YES" -eq 1 ]; then
                # shellcheck disable=SC2086
                as_root xbps-install -y $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            else
                # shellcheck disable=SC2086
                as_root xbps-install $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            fi
            ;;
        emerge)
            # shellcheck disable=SC2086
            as_root emerge --ask=n $AVAILABLE_PACKAGES || warn "One or more dependency packages failed to install; continuing."
            ;;
    esac
}

install_files() {
    if [ "$DRY_RUN" -eq 1 ]; then
        say "+ mkdir -p $DEST $BINDIR"
        say "+ copy project files to $DEST"
        say "+ create launcher $BINDIR/ish-aok-config"
        return 0
    fi

    if ! mkdir -p "$DEST" "$BINDIR" 2>/dev/null; then
        if [ "$(id -u 2>/dev/null || printf 1)" -ne 0 ]; then
            if have doas; then exec doas env PREFIX="$PREFIX" DESTDIR="${DESTDIR:-}" ISH_AOK_SKIP_DEPENDENCIES=1 sh "$0" --skip-deps
            elif have sudo; then exec sudo env PREFIX="$PREFIX" DESTDIR="${DESTDIR:-}" ISH_AOK_SKIP_DEPENDENCIES=1 sh "$0" --skip-deps
            fi
        fi
        warn "Unable to create $DEST or $BINDIR"
        return 1
    fi

    # Avoid recursively copying a previous destination when installing in-tree.
    for _if_item in "$SELF"/*; do
        [ "$_if_item" = "$DEST" ] && continue
        cp -R "$_if_item" "$DEST"/
    done

    cat >"$BINDIR/ish-aok-config" <<LAUNCH
#!/bin/sh
exec "$PREFIX/lib/ish-aok-config/ish-aok-config" "\$@"
LAUNCH
    chmod 755 "$BINDIR/ish-aok-config" "$DEST/ish-aok-config"
    say "Installed: $BINDIR/ish-aok-config"
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --check) CHECK_ONLY=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        --with-builders) WITH_BUILDERS=1 ;;
        --interactive) ASSUME_YES=0 ;;
        --prefix)
            shift
            [ "$#" -gt 0 ] || { warn "--prefix requires a path"; exit 2; }
            PREFIX=$1
            DEST=${DESTDIR:-}$PREFIX/lib/ish-aok-config
            BINDIR=${DESTDIR:-}$PREFIX/bin
            ;;
        -h|--help) usage; exit 0 ;;
        *) warn "Unknown option: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

detect_system
if [ "$SKIP_DEPS" -ne 1 ] && [ -z "${DESTDIR:-}" ]; then
    scan_dependencies
    print_scan
    if [ "$CHECK_ONLY" -eq 1 ]; then
        [ -z "$MISSING" ]
        exit $?
    fi
    install_packages
    if [ "$DRY_RUN" -ne 1 ]; then
        scan_dependencies
        [ -z "$MISSING" ] || warn "Some optional or unavailable features remain missing: $MISSING"
    fi
elif [ "$CHECK_ONLY" -eq 1 ]; then
    say "Dependency scan skipped."
    exit 0
fi

install_files
