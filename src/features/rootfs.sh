# shellcheck shell=bash
# ROOTFS BUILDER — expanded
#
# Distros: Debian/Devuan/Ubuntu/Kali (mmdebstrap, debootstrap, cdebootstrap,
#          qemu-debootstrap, or multistrap), Alpine (apk.static),
#          Arch (pacstrap/tarball), Fedora (dnf --installroot + repofrompath),
#          Void (official ROOTFS tarball).
# Extras : build presets, foreign-arch builds via qemu-user-static + binfmt,
#          in-rootfs post-config (users, DNS, hosts, timezone, sshd),
#          build manifest, multi-format compression, and a management menu
#          (enter chroot, inspect, compress, delete).
###############################################################################

ROOTFS_BASE="/opt/rootfs"

# Reports are written into the private 0700 workspace, never into a shared
# world-writable directory: systui runs as root and a predictable path in /tmp
# lets any local user pre-create a symlink and redirect the write (CWE-59).
rootfs_report_file() {
    printf '%s/rootfs-report' "${SYSTUI_TMP:?private workspace is not initialized}"
}

rootfs_fetch_text() { # <url>
    if command -v curl >/dev/null 2>&1; then
        curl -4 -LfsS --connect-timeout 10 --max-time 120 "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -4 -qO- -T 120 "$1"
    else
        return 127
    fi
}

rootfs_fetch_file() { # <url> <destination>
    if command -v curl >/dev/null 2>&1; then
        curl -4 -fL --retry 3 --connect-timeout 10 --max-time 600 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -4 -q -T 600 -O "$2" "$1"
    else
        return 127
    fi
}

rootfs_backend_available() { # <backend>
    case "$1" in
        mmdebstrap|debootstrap|cdebootstrap|multistrap|pacstrap|dnf|zypper)
            command -v "$1" >/dev/null 2>&1
            ;;
        qemu-debootstrap)
            command -v qemu-debootstrap >/dev/null 2>&1 &&
                command -v debootstrap >/dev/null 2>&1
            ;;
        apk-static)
            command -v tar >/dev/null 2>&1 &&
                command -v gzip >/dev/null 2>&1 &&
                { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }
            ;;
        arch-bootstrap)
            command -v tar >/dev/null 2>&1 && command -v zstd >/dev/null 2>&1 &&
                { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }
            ;;
        gentoo-stage3|void-tarball)
            command -v tar >/dev/null 2>&1 && command -v xz >/dev/null 2>&1 &&
                { command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; }
            ;;
        *) return 1 ;;
    esac
}

rootfs_backend_status() { # <backend>
    rootfs_backend_available "$1" && printf 'available\n' || printf 'missing prerequisites\n'
}

rootfs_backend_supported() { # <distro> <backend>
    case "$1:$2" in
        debian:mmdebstrap|debian:debootstrap|debian:cdebootstrap|debian:qemu-debootstrap|debian:multistrap|\
        devuan:mmdebstrap|devuan:debootstrap|devuan:cdebootstrap|devuan:qemu-debootstrap|devuan:multistrap|\
        ubuntu:mmdebstrap|ubuntu:debootstrap|ubuntu:cdebootstrap|ubuntu:qemu-debootstrap|ubuntu:multistrap|\
        kali:mmdebstrap|kali:debootstrap|kali:cdebootstrap|kali:qemu-debootstrap|kali:multistrap|\
        alpine:apk-static|arch:pacstrap|arch:arch-bootstrap|fedora:dnf|\
        opensuse:zypper|tumbleweed:zypper|gentoo:gentoo-stage3|void:void-tarball)
            return 0
            ;;
        *) return 1 ;;
    esac
}

rootfs_resolve_backend() { # <distro> <selected>
    local distro="$1" selected="${2:-auto}"
    if [ "$selected" != auto ]; then
        rootfs_backend_supported "$distro" "$selected" || return 1
        printf '%s\n' "$selected"
        return 0
    fi
    case "$distro" in
        debian|devuan|ubuntu|kali)
            if rootfs_backend_available mmdebstrap; then printf 'mmdebstrap\n'
            elif rootfs_backend_available debootstrap; then printf 'debootstrap\n'
            elif rootfs_backend_available cdebootstrap; then printf 'cdebootstrap\n'
            elif rootfs_backend_available multistrap; then printf 'multistrap\n'
            else return 1; fi
            ;;
        alpine) printf 'apk-static\n' ;;
        arch)
            if rootfs_backend_available pacstrap; then printf 'pacstrap\n'
            else printf 'arch-bootstrap\n'; fi
            ;;
        fedora) printf 'dnf\n' ;;
        opensuse|tumbleweed) printf 'zypper\n' ;;
        gentoo) printf 'gentoo-stage3\n' ;;
        void) printf 'void-tarball\n' ;;
        *) return 1 ;;
    esac
}

rootfs_backend_menu() { # <distro>
    local distro="$1" selected
    case "$distro" in
        debian|devuan|ubuntu|kali)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — mmdebstrap, debootstrap, cdebootstrap, then multistrap" on \
                mmdebstrap "mmdebstrap — modern APT bootstrap ($(rootfs_backend_status mmdebstrap))" off \
                debootstrap "debootstrap — classic two-stage bootstrap ($(rootfs_backend_status debootstrap))" off \
                cdebootstrap "cdebootstrap — compiled minimal bootstrap ($(rootfs_backend_status cdebootstrap))" off \
                qemu-debootstrap "qemu-debootstrap — foreign-architecture wrapper ($(rootfs_backend_status qemu-debootstrap))" off \
                multistrap "multistrap — configuration-driven APT bootstrap ($(rootfs_backend_status multistrap))" off) || return 1
            ;;
        arch)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — prefer pacstrap, then official bootstrap tarball" on \
                pacstrap "pacstrap — arch-install-scripts ($(rootfs_backend_status pacstrap))" off \
                arch-bootstrap "Official Arch bootstrap tarball ($(rootfs_backend_status arch-bootstrap))" off) || return 1
            ;;
        alpine)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — apk.static" on \
                apk-static "Downloaded apk.static ($(rootfs_backend_status apk-static))" off) || return 1
            ;;
        fedora)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — DNF installroot" on \
                dnf "dnf --installroot ($(rootfs_backend_status dnf))" off) || return 1
            ;;
        opensuse|tumbleweed)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — Zypper root mode" on \
                zypper "zypper --root ($(rootfs_backend_status zypper))" off) || return 1
            ;;
        gentoo)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — official stage3 tarball" on \
                gentoo-stage3 "Official Gentoo stage3 ($(rootfs_backend_status gentoo-stage3))" off) || return 1
            ;;
        void)
            selected=$(tui_radio "Rootfs Builder 2/13" "Bootstrap backend (SPACE selects):" \
                auto "Automatic — official ROOTFS tarball" on \
                void-tarball "Official Void ROOTFS tarball ($(rootfs_backend_status void-tarball))" off) || return 1
            ;;
    esac
    rootfs_resolve_backend "$distro" "$selected"
}

# Debian-family backend configuration is kept separate from the general build
# state so interrupted builds can be resumed with the exact same tool options.
rootfs_backend_config_defaults() { # <distro> <backend>
    local distro="$1" backend="$2"
    ROOTFS_BACKEND_VARIANT=minbase
    ROOTFS_BACKEND_COMPONENTS=main
    [ "$distro" = ubuntu ] && ROOTFS_BACKEND_COMPONENTS="main,universe"
    ROOTFS_BACKEND_INCLUDE=""
    ROOTFS_BACKEND_EXCLUDE=""
    ROOTFS_BACKEND_KEYRING_MODE=auto
    ROOTFS_BACKEND_KEYRING_PATH=""
    ROOTFS_BACKEND_MERGED=auto
    ROOTFS_BACKEND_VERBOSE=no
    ROOTFS_MMDEBSTRAP_MODE=root
    ROOTFS_MMDEBSTRAP_PRUNE=no
    ROOTFS_CDEBOOTSTRAP_CONFIGDIR=""
    ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH=no
    ROOTFS_MULTISTRAP_CLEANUP=yes
    ROOTFS_MULTISTRAP_IMPORTANT=no
    ROOTFS_MULTISTRAP_MARKAUTO=yes
    ROOTFS_MULTISTRAP_KEYRING_PACKAGE=""
    ROOTFS_MULTISTRAP_CONFIG=""
    case "$backend" in
        cdebootstrap) ROOTFS_BACKEND_VARIANT=minimal ;;
        multistrap) ROOTFS_BACKEND_VARIANT=required ;;
    esac
}

rootfs_backend_valid_components() {
    [ -n "$1" ] && printf '%s' "$1" | grep -Eq '^[A-Za-z0-9+.-]+([,[:space:]]+[A-Za-z0-9+.-]+)*$'
}

rootfs_backend_edit_packages() { # <title> <current>; prints sanitized list
    local value
    value=$(tui_input "$1" "Space-separated native package names (blank for none):" "$2") || return 1
    rootfs_sanitize_packages "$value"
}

rootfs_backend_keyring_menu() {
    local mode path
    mode=$(tui_radio "Repository verification" "Archive signing keyring:" \
        auto "Automatically select the distribution keyring" "$([ "$ROOTFS_BACKEND_KEYRING_MODE" = auto ] && echo on || echo off)" \
        custom "Use a custom keyring file" "$([ "$ROOTFS_BACKEND_KEYRING_MODE" = custom ] && echo on || echo off)") || return 0
    if [ "$mode" = custom ]; then
        path=$(tui_input "Custom keyring" "Absolute path to a readable keyring file:" "$ROOTFS_BACKEND_KEYRING_PATH") || return 0
        case "$path" in /*) ;; *) tui_msg "Invalid keyring" "The keyring path must be absolute."; return 0;; esac
        [ -r "$path" ] || { tui_msg "Invalid keyring" "The selected keyring is not readable:\n$path"; return 0; }
        ROOTFS_BACKEND_KEYRING_PATH="$path"
    fi
    ROOTFS_BACKEND_KEYRING_MODE="$mode"
}

rootfs_backend_config_menu() { # <distro> <backend> [preserve]
    local distro="$1" backend="$2" c value
    [ "${3:-reset}" = preserve ] || rootfs_backend_config_defaults "$distro" "$backend"
    while true; do
        case "$backend" in
            debootstrap|qemu-debootstrap)
                c=$(tui_menu "$backend configuration" "Configure the selected bootstrap tool:" \
                    variant "Variant: $ROOTFS_BACKEND_VARIANT" \
                    components "Archive components: $ROOTFS_BACKEND_COMPONENTS" \
                    include "Bootstrap include: ${ROOTFS_BACKEND_INCLUDE:-none}" \
                    exclude "Bootstrap exclude: ${ROOTFS_BACKEND_EXCLUDE:-none}" \
                    merged "Merged /usr: $ROOTFS_BACKEND_MERGED" \
                    keyring "Keyring: $ROOTFS_BACKEND_KEYRING_MODE" \
                    verbose "Verbose output: $ROOTFS_BACKEND_VERBOSE" \
                    "done" "Use these settings") || return 1
                case "$c" in
                    variant) ROOTFS_BACKEND_VARIANT=$(tui_radio "debootstrap variant" "Base package set:" minbase "Required packages plus apt" on buildd "Build environment" off default "Required and important packages" off) || true ;;
                    components) value=$(tui_input "Archive components" "Comma-separated components:" "$ROOTFS_BACKEND_COMPONENTS") || continue; rootfs_backend_valid_components "$value" && ROOTFS_BACKEND_COMPONENTS="${value// /,}" || tui_msg "Invalid components" "Use names separated by commas, such as main,contrib,non-free." ;;
                    include) value=$(rootfs_backend_edit_packages "Bootstrap include" "$ROOTFS_BACKEND_INCLUDE") && ROOTFS_BACKEND_INCLUDE="$value" ;;
                    exclude) value=$(rootfs_backend_edit_packages "Bootstrap exclude" "$ROOTFS_BACKEND_EXCLUDE") && ROOTFS_BACKEND_EXCLUDE="$value" ;;
                    merged) ROOTFS_BACKEND_MERGED=$(tui_radio "Merged /usr" "Control /bin, /sbin and /lib symlinks:" auto "Tool/release default" on yes "Force merged /usr" off no "Force split /usr" off) || true ;;
                    keyring) rootfs_backend_keyring_menu ;;
                    verbose) [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && ROOTFS_BACKEND_VERBOSE=no || ROOTFS_BACKEND_VERBOSE=yes ;;
                    done) return 0 ;;
                esac ;;
            mmdebstrap)
                c=$(tui_menu "mmdebstrap configuration" "Configure mmdebstrap:" \
                    variant "Variant: $ROOTFS_BACKEND_VARIANT" \
                    mode "Execution mode: $ROOTFS_MMDEBSTRAP_MODE" \
                    components "Archive components: $ROOTFS_BACKEND_COMPONENTS" \
                    include "Bootstrap include: ${ROOTFS_BACKEND_INCLUDE:-none}" \
                    exclude "APT remove patterns: ${ROOTFS_BACKEND_EXCLUDE:-none}" \
                    keyring "Keyring: $ROOTFS_BACKEND_KEYRING_MODE" \
                    prune "Exclude docs/locales: $ROOTFS_MMDEBSTRAP_PRUNE" \
                    verbose "Verbose output: $ROOTFS_BACKEND_VERBOSE" \
                    "done" "Use these settings") || return 1
                case "$c" in
                    variant) ROOTFS_BACKEND_VARIANT=$(tui_radio "mmdebstrap variant" "Base package set:" minbase "Minimal debootstrap-compatible root" on apt "Essential packages plus apt" off required "Required priority" off important "Required and important priority" off standard "Standard system" off buildd "Build environment" off) || true ;;
                    mode) ROOTFS_MMDEBSTRAP_MODE=$(tui_radio "mmdebstrap mode" "Filesystem ownership/execution mode:" root "Run directly as root" on auto "Let mmdebstrap choose" off unshare "User namespace mode" off) || true ;;
                    components) value=$(tui_input "Archive components" "Comma-separated components:" "$ROOTFS_BACKEND_COMPONENTS") || continue; rootfs_backend_valid_components "$value" && ROOTFS_BACKEND_COMPONENTS="${value// /,}" || tui_msg "Invalid components" "Use names separated by commas." ;;
                    include) value=$(rootfs_backend_edit_packages "Bootstrap include" "$ROOTFS_BACKEND_INCLUDE") && ROOTFS_BACKEND_INCLUDE="$value" ;;
                    exclude) value=$(rootfs_backend_edit_packages "APT remove patterns" "$ROOTFS_BACKEND_EXCLUDE") && ROOTFS_BACKEND_EXCLUDE="$value" ;;
                    keyring) rootfs_backend_keyring_menu ;;
                    prune) [ "$ROOTFS_MMDEBSTRAP_PRUNE" = yes ] && ROOTFS_MMDEBSTRAP_PRUNE=no || ROOTFS_MMDEBSTRAP_PRUNE=yes ;;
                    verbose) [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && ROOTFS_BACKEND_VERBOSE=no || ROOTFS_BACKEND_VERBOSE=yes ;;
                    done) return 0 ;;
                esac ;;
            cdebootstrap)
                c=$(tui_menu "cdebootstrap configuration" "Configure cdebootstrap:" \
                    flavour "Flavour: $ROOTFS_BACKEND_VARIANT" \
                    include "Bootstrap include: ${ROOTFS_BACKEND_INCLUDE:-none}" \
                    exclude "Bootstrap exclude: ${ROOTFS_BACKEND_EXCLUDE:-none}" \
                    configdir "Configuration directory: ${ROOTFS_CDEBOOTSTRAP_CONFIGDIR:-system default}" \
                    keyring "Keyring: $ROOTFS_BACKEND_KEYRING_MODE" \
                    unauth "Allow unauthenticated: $ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH" \
                    verbose "Verbose output: $ROOTFS_BACKEND_VERBOSE" \
                    "done" "Use these settings") || return 1
                case "$c" in
                    flavour) ROOTFS_BACKEND_VARIANT=$(tui_radio "cdebootstrap flavour" "Base package set:" minimal "Essential packages plus apt" on standard "Required and important packages" off build "Build environment" off) || true ;;
                    include) value=$(rootfs_backend_edit_packages "Bootstrap include" "$ROOTFS_BACKEND_INCLUDE") && ROOTFS_BACKEND_INCLUDE="$value" ;;
                    exclude) value=$(rootfs_backend_edit_packages "Bootstrap exclude" "$ROOTFS_BACKEND_EXCLUDE") && ROOTFS_BACKEND_EXCLUDE="$value" ;;
                    configdir) value=$(tui_input "cdebootstrap config" "Optional absolute configuration directory (blank for system default):" "$ROOTFS_CDEBOOTSTRAP_CONFIGDIR") || continue; if [ -z "$value" ]; then ROOTFS_CDEBOOTSTRAP_CONFIGDIR=""; elif [ "${value#/}" != "$value" ] && [ -d "$value" ]; then ROOTFS_CDEBOOTSTRAP_CONFIGDIR="$value"; else tui_msg "Invalid directory" "Select an existing absolute directory or leave blank."; fi ;;
                    keyring) rootfs_backend_keyring_menu ;;
                    unauth) if [ "$ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH" = yes ]; then ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH=no; elif tui_yesno "Unsafe repository mode" "Disable package authentication? This permits unverified packages and is not recommended."; then ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH=yes; fi ;;
                    verbose) [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && ROOTFS_BACKEND_VERBOSE=no || ROOTFS_BACKEND_VERBOSE=yes ;;
                    done) return 0 ;;
                esac ;;
            multistrap)
                c=$(tui_menu "multistrap configuration" "Configure the generated multistrap file:" \
                    include "Repository packages: ${ROOTFS_BACKEND_INCLUDE:-required set only}" \
                    cleanup "Clean downloaded package data: $ROOTFS_MULTISTRAP_CLEANUP" \
                    important "Add Priority important packages: $ROOTFS_MULTISTRAP_IMPORTANT" \
                    markauto "Track dependency auto/manual state: $ROOTFS_MULTISTRAP_MARKAUTO" \
                    keypkg "Archive keyring package: ${ROOTFS_MULTISTRAP_KEYRING_PACKAGE:-automatic}" \
                    custom "Custom config file: ${ROOTFS_MULTISTRAP_CONFIG:-generated}" \
                    "done" "Use these settings") || return 1
                case "$c" in
                    include) value=$(rootfs_backend_edit_packages "multistrap packages" "$ROOTFS_BACKEND_INCLUDE") && ROOTFS_BACKEND_INCLUDE="$value" ;;
                    cleanup) [ "$ROOTFS_MULTISTRAP_CLEANUP" = yes ] && ROOTFS_MULTISTRAP_CLEANUP=no || ROOTFS_MULTISTRAP_CLEANUP=yes ;;
                    important) [ "$ROOTFS_MULTISTRAP_IMPORTANT" = yes ] && ROOTFS_MULTISTRAP_IMPORTANT=no || ROOTFS_MULTISTRAP_IMPORTANT=yes ;;
                    markauto) [ "$ROOTFS_MULTISTRAP_MARKAUTO" = yes ] && ROOTFS_MULTISTRAP_MARKAUTO=no || ROOTFS_MULTISTRAP_MARKAUTO=yes ;;
                    keypkg) value=$(tui_input "Archive keyring package" "Native package containing repository signing keys (blank for automatic):" "$ROOTFS_MULTISTRAP_KEYRING_PACKAGE") || continue; if [ -z "$value" ] || rootfs_valid_package_name "$value"; then ROOTFS_MULTISTRAP_KEYRING_PACKAGE="$value"; else tui_msg "Invalid package" "Enter one native package name."; fi ;;
                    custom) value=$(tui_input "Custom multistrap config" "Absolute readable config file (blank to generate one):" "$ROOTFS_MULTISTRAP_CONFIG") || continue; if [ -z "$value" ]; then ROOTFS_MULTISTRAP_CONFIG=""; elif [ "${value#/}" != "$value" ] && [ -r "$value" ]; then ROOTFS_MULTISTRAP_CONFIG="$value"; else tui_msg "Invalid config" "Select an absolute readable file or leave blank."; fi ;;
                    done) return 0 ;;
                esac ;;
        esac
    done
}

rootfs_backend_config_file() { printf '%s/.systui-backend.conf\n' "$1"; }

rootfs_backend_config_write() { # <target>
    local file; file=$(rootfs_backend_config_file "$1")
    cat > "$file" <<EOF
VARIANT="$(rootfs_state_escape "$ROOTFS_BACKEND_VARIANT")"
COMPONENTS="$(rootfs_state_escape "$ROOTFS_BACKEND_COMPONENTS")"
INCLUDE="$(rootfs_state_escape "$ROOTFS_BACKEND_INCLUDE")"
EXCLUDE="$(rootfs_state_escape "$ROOTFS_BACKEND_EXCLUDE")"
KEYRING_MODE="$(rootfs_state_escape "$ROOTFS_BACKEND_KEYRING_MODE")"
KEYRING_PATH="$(rootfs_state_escape "$ROOTFS_BACKEND_KEYRING_PATH")"
MERGED_USR="$(rootfs_state_escape "$ROOTFS_BACKEND_MERGED")"
VERBOSE="$(rootfs_state_escape "$ROOTFS_BACKEND_VERBOSE")"
MMDEBSTRAP_MODE="$(rootfs_state_escape "$ROOTFS_MMDEBSTRAP_MODE")"
MMDEBSTRAP_PRUNE="$(rootfs_state_escape "$ROOTFS_MMDEBSTRAP_PRUNE")"
CDEBOOTSTRAP_CONFIGDIR="$(rootfs_state_escape "$ROOTFS_CDEBOOTSTRAP_CONFIGDIR")"
CDEBOOTSTRAP_ALLOW_UNAUTH="$(rootfs_state_escape "$ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH")"
MULTISTRAP_CLEANUP="$(rootfs_state_escape "$ROOTFS_MULTISTRAP_CLEANUP")"
MULTISTRAP_IMPORTANT="$(rootfs_state_escape "$ROOTFS_MULTISTRAP_IMPORTANT")"
MULTISTRAP_MARKAUTO="$(rootfs_state_escape "$ROOTFS_MULTISTRAP_MARKAUTO")"
MULTISTRAP_KEYRING_PACKAGE="$(rootfs_state_escape "$ROOTFS_MULTISTRAP_KEYRING_PACKAGE")"
MULTISTRAP_CONFIG="$(rootfs_state_escape "$ROOTFS_MULTISTRAP_CONFIG")"
EOF
    chmod 600 "$file"
}

rootfs_backend_config_load() { # <target> <distro> <backend>
    local target="$1" distro="$2" backend="$3" file key value
    rootfs_backend_config_defaults "$distro" "$backend"
    file=$(rootfs_backend_config_file "$target")
    [ -r "$file" ] || return 0
    while IFS='=' read -r key value; do
        value=${value#\"}; value=${value%\"}
        case "$key" in
            VARIANT) ROOTFS_BACKEND_VARIANT="$value" ;;
            COMPONENTS) ROOTFS_BACKEND_COMPONENTS="$value" ;;
            INCLUDE) ROOTFS_BACKEND_INCLUDE="$value" ;;
            EXCLUDE) ROOTFS_BACKEND_EXCLUDE="$value" ;;
            KEYRING_MODE) ROOTFS_BACKEND_KEYRING_MODE="$value" ;;
            KEYRING_PATH) ROOTFS_BACKEND_KEYRING_PATH="$value" ;;
            MERGED_USR) ROOTFS_BACKEND_MERGED="$value" ;;
            VERBOSE) ROOTFS_BACKEND_VERBOSE="$value" ;;
            MMDEBSTRAP_MODE) ROOTFS_MMDEBSTRAP_MODE="$value" ;;
            MMDEBSTRAP_PRUNE) ROOTFS_MMDEBSTRAP_PRUNE="$value" ;;
            CDEBOOTSTRAP_CONFIGDIR) ROOTFS_CDEBOOTSTRAP_CONFIGDIR="$value" ;;
            CDEBOOTSTRAP_ALLOW_UNAUTH) ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH="$value" ;;
            MULTISTRAP_CLEANUP) ROOTFS_MULTISTRAP_CLEANUP="$value" ;;
            MULTISTRAP_IMPORTANT) ROOTFS_MULTISTRAP_IMPORTANT="$value" ;;
            MULTISTRAP_MARKAUTO) ROOTFS_MULTISTRAP_MARKAUTO="$value" ;;
            MULTISTRAP_KEYRING_PACKAGE) ROOTFS_MULTISTRAP_KEYRING_PACKAGE="$value" ;;
            MULTISTRAP_CONFIG) ROOTFS_MULTISTRAP_CONFIG="$value" ;;
        esac
    done < "$file"
}

rootfs_backend_config_summary() { # <backend>
    case "$1" in
        debootstrap|qemu-debootstrap)
            printf 'variant=%s, components=%s, merged-usr=%s' "$ROOTFS_BACKEND_VARIANT" "$ROOTFS_BACKEND_COMPONENTS" "$ROOTFS_BACKEND_MERGED" ;;
        mmdebstrap)
            printf 'variant=%s, mode=%s, components=%s, prune=%s' "$ROOTFS_BACKEND_VARIANT" "$ROOTFS_MMDEBSTRAP_MODE" "$ROOTFS_BACKEND_COMPONENTS" "$ROOTFS_MMDEBSTRAP_PRUNE" ;;
        cdebootstrap)
            printf 'flavour=%s, configdir=%s, authenticated=%s' "$ROOTFS_BACKEND_VARIANT" "${ROOTFS_CDEBOOTSTRAP_CONFIGDIR:-default}" "$([ "$ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH" = yes ] && echo no || echo yes)" ;;
        multistrap)
            printf 'config=%s, cleanup=%s, important=%s, markauto=%s' "${ROOTFS_MULTISTRAP_CONFIG:-generated}" "$ROOTFS_MULTISTRAP_CLEANUP" "$ROOTFS_MULTISTRAP_IMPORTANT" "$ROOTFS_MULTISTRAP_MARKAUTO" ;;
        *)
            printf 'backend defaults' ;;
    esac
}

rootfs_multistrap_config_write() { # <file> <arch> <target> <mirror> <release> <components> <packages> <keyring-package>
    local file="$1" arch="$2" target="$3" mirror="$4" release="$5"
    local components="$6" packages="$7" keyring_package="$8"
    local source="$mirror"
    [ -n "$components" ] && source="$source ${components//,/ }"
    cat > "$file" <<EOF
[General]
arch=$arch
directory=$target
cleanup=$ROOTFS_MULTISTRAP_CLEANUP
noauth=false
unpack=true
bootstrap=Base
aptsources=Base
markauto=$ROOTFS_MULTISTRAP_MARKAUTO
addimportant=$ROOTFS_MULTISTRAP_IMPORTANT
allowrecommends=false

[Base]
packages=$packages
source=$source
suite=$release
keyring=$keyring_package
omitdebsrc=true
EOF
}

rootfs_backend_reconfigure() { # <target>
    local target="$1" distro backend
    distro=$(rootfs_state_get "$target" DISTRO 2>/dev/null || true)
    backend=$(rootfs_state_get "$target" BACKEND 2>/dev/null || true)
    case "$distro:$backend" in
        debian:*|devuan:*|ubuntu:*|kali:*) ;;
        *) tui_msg "Backend configuration" "This build does not use a configurable Debian-family backend."; return 0 ;;
    esac
    case "$backend" in mmdebstrap|debootstrap|cdebootstrap|qemu-debootstrap|multistrap) ;; *) tui_msg "Backend configuration" "No configurable backend was recorded for this build."; return 0;; esac
    rootfs_backend_config_load "$target" "$distro" "$backend"
    rootfs_backend_config_menu "$distro" "$backend" preserve || return 0
    rootfs_backend_config_write "$target"
    tui_msg "Backend configuration" "Saved $backend settings for future resume/rebuild operations."
}

# Host arch in deb terms, for foreign-arch detection.
host_debarch() {
    case "$(uname -m)" in
        x86_64)        echo amd64 ;;
        aarch64)       echo arm64 ;;
        armv7l|armv6l) echo armhf ;;
        i686|i386)     echo i386 ;;
        *)             uname -m ;;
    esac
}

qemu_bin_for() { # deb arch -> qemu-user-static binary name
    case "$1" in
        amd64) echo qemu-x86_64-static ;;
        arm64) echo qemu-aarch64-static ;;
        armhf) echo qemu-arm-static ;;
        i386)  echo qemu-i386-static ;;
        *)     echo "" ;;
    esac
}

# Returns 0 if <target debarch> needs qemu on this host.
needs_qemu() {
    local t="$1" h; h=$(host_debarch)
    [ "$t" = "$h" ] && return 1
    # 32-bit x86 runs natively on x86_64
    [ "$h" = amd64 ] && [ "$t" = i386 ] && return 1
    return 0
}

# Copy the qemu-user-static binary into the rootfs so chroots work.
setup_qemu_chroot() { # setup_qemu_chroot <target> <debarch>
    local target="$1" qbin
    qbin=$(qemu_bin_for "$2")
    [ -z "$qbin" ] && { warn "No qemu mapping for arch $2 — chroot steps will fail."; return 1; }
    if ! command -v "$qbin" >/dev/null; then
        warn "$qbin not found on host. Install qemu-user-static (+ binfmt-support) for foreign-arch chroots."
        return 1
    fi
    mkdir -p "$target/usr/bin"
    cp "$(command -v "$qbin")" "$target/usr/bin/" || return 1
    log "qemu: copied $qbin into $target"
    [ -d /proc/sys/fs/binfmt_misc ] || warn "binfmt_misc not mounted — foreign chroot may not exec."
    return 0
}



rootfs_valid_package_name() {
    # Common package syntax across supported managers: names, versions, slots,
    # repository qualifiers and architecture suffixes. Shell metacharacters,
    # paths and option-like values are intentionally rejected.
    local p="$1"
    [ -n "$p" ] && [ "${p#-}" = "$p" ] &&
        printf '%s' "$p" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9+_.:@%~^=-]*$'
}

rootfs_sanitize_packages() { # <space-separated list>
    local input="$1" p out=""
    for p in $input; do
        if rootfs_valid_package_name "$p"; then
            case " $out " in *" $p "*) ;; *) out="$out $p" ;; esac
        else
            warn "Rejected unsafe or invalid package name: $p"
            return 1
        fi
    done
    printf '%s\n' "${out# }"
}

rootfs_valid_hostname() {
    [ ${#1} -le 253 ] && printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'
}
rootfs_valid_username() { printf '%s' "$1" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$'; }
rootfs_valid_port() { case "$1" in ''|*[!0-9]*) return 1;; esac; [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
rootfs_valid_timezone() {
    case "$1" in ''|/*|*..*|*[!A-Za-z0-9_+./-]*) return 1;; esac
    return 0
}
rootfs_valid_locale() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9_@.-]+$'; }

rootfs_target_arch() { # <target>
    local t="$1" a
    a=$(rootfs_state_get "$t" ARCH 2>/dev/null || true)
    [ -n "$a" ] || a=$(sed -nE 's/^Architecture:[[:space:]]*//p' "$t/var/lib/dpkg/status" 2>/dev/null | head -n1)
    [ -n "$a" ] || a=$(host_debarch)
    printf '%s\n' "$a"
}

rootfs_exec_raw() { # <target> <command> [args...]
    local t="$1" cmd="$2" arch qbin; shift 2
    arch=$(rootfs_target_arch "$t")
    if needs_qemu "$arch"; then
        qbin=$(qemu_bin_for "$arch")
        [ -n "$qbin" ] || return 126
        [ -x "$t/usr/bin/$qbin" ] || setup_qemu_chroot "$t" "$arch" || return 126
        chroot "$t" "/usr/bin/$qbin" "$cmd" "$@"
    else
        chroot "$t" "$cmd" "$@"
    fi
}

# Persistent interactive chroot-entry settings.
rootfs_chroot_options_file() { printf '%s/etc/systui-chroot.conf\n' "$1"; }
rootfs_chroot_option_get() { # <target> <key> <default>
    local f key value
    f=$(rootfs_chroot_options_file "$1"); key="$2"
    value=$(awk -F= -v k="$key" '$1==k{sub(/^[^=]*=/,""); gsub(/^"|"$/,""); print; exit}' "$f" 2>/dev/null || true)
    printf '%s\n' "${value:-$3}"
}
rootfs_chroot_option_set() { # <target> <key> <value>
    local f key value tmp
    f=$(rootfs_chroot_options_file "$1"); key="$2"; value="$3"; tmp="${f}.tmp.$$"
    mkdir -p "$(dirname "$f")"
    [ -f "$f" ] && awk -F= -v k="$key" '$1!=k{print}' "$f" > "$tmp" || : > "$tmp"
    printf '%s="%s"\n' "$key" "$(printf '%s' "$value" | tr '\n\r"' '   ')" >> "$tmp"
    mv -f "$tmp" "$f"
}
rootfs_shell_path() { # <target> <shell-name-or-path>
    local t="$1" shv="$2" p
    case "$shv" in /*) p="$shv";; bash|sh|dash|ash|zsh|ksh) p="/bin/$shv";; fish) p="/usr/bin/fish";; *) p="/bin/sh";; esac
    [ -x "$t$p" ] && printf '%s\n' "$p" || printf '/bin/sh\n'
}

rootfs_chroot_options_menu() { # <target>
    local t="$1" c mount_aok shell workdir launch_cmd boot_cmd
    while true; do
        mount_aok=$(rootfs_chroot_option_get "$t" MOUNT_AOK yes)
        shell=$(rootfs_chroot_option_get "$t" SHELL /bin/bash)
        workdir=$(rootfs_chroot_option_get "$t" WORKDIR /root)
        launch_cmd=$(rootfs_chroot_option_get "$t" LAUNCH_CMD "")
        boot_cmd=$(rootfs_chroot_option_get "$t" BOOT_CMD "")
        c=$(tui_menu "Chroot entry options" "Configure settings applied before entering $(basename "$t"):" \
            aok "Mount host /AOK at /AOK: $mount_aok" \
            shell "Interactive shell: $shell" \
            defaultshell "Set account default shell" \
            workdir "Starting directory: $workdir" \
            launchcmd "Launch command: ${launch_cmd:-default Bash login shell}" \
            bootcmd "Boot command: ${boot_cmd:-disabled}" \
            config "Open full rootfs configuration menu" \
            back "Back") || return 0
        case "$c" in
            aok)
                mount_aok=$(tui_radio "Mount /AOK" "Bind-mount the host /AOK directory inside the chroot:" \
                    yes "Enabled" "$([ "$mount_aok" = yes ] && echo on || echo off)" \
                    no "Disabled" "$([ "$mount_aok" != yes ] && echo on || echo off)") || continue
                rootfs_chroot_option_set "$t" MOUNT_AOK "$mount_aok" ;;
            shell)
                local shv
                shv=$(tui_radio "Chroot shell" "Shell used when entering the rootfs:" bash "/bin/bash" on sh "/bin/sh (portable)" off zsh "/bin/zsh" off fish "/usr/bin/fish" off custom "Custom path" off) || continue
                if [ "$shv" = custom ]; then shv=$(tui_input "Shell path" "Absolute shell path inside the rootfs:" "$shell") || continue; fi
                shv=$(rootfs_shell_path "$t" "$shv")
                rootfs_chroot_option_set "$t" SHELL "$shv" ;;
            defaultshell)
                local user shv path
                user=$(tui_input "Account" "Account whose login shell should change:" root) || continue
                rootfs_valid_username "$user" || { tui_msg "Invalid account" "Enter a valid local account name."; continue; }
                shv=$(tui_radio "Default shell" "Select the account login shell:" bash "/bin/bash" on sh "/bin/sh" off zsh "/bin/zsh" off fish "/usr/bin/fish" off) || continue
                path=$(rootfs_shell_path "$t" "$shv")
                rootfs_chroot_exec "$t" "Set default shell for $user" "chsh -s '$path' '$user'" && rootfs_chroot_option_set "$t" SHELL "$path" ;;
            workdir)
                workdir=$(tui_input "Starting directory" "Absolute directory inside the rootfs:" "$workdir") || continue
                case "$workdir" in /*) ;; *) tui_msg "Invalid directory" "Use an absolute path such as /root or /AOK."; continue;; esac
                mkdir -p "$t$workdir" || { tui_msg "Failed" "Could not create $workdir in the rootfs."; continue; }
                rootfs_chroot_option_set "$t" WORKDIR "$workdir" ;;
            launchcmd)
                launch_cmd=$(tui_input "Launch command" "Command executed when entering the rootfs. Leave empty to start the configured Bash login shell:" "$launch_cmd") || continue
                rootfs_chroot_option_set "$t" LAUNCH_CMD "$launch_cmd" ;;
            bootcmd)
                boot_cmd=$(tui_input "Boot command" "Optional command executed before the launch command on every chroot entry. Leave empty to disable:" "$boot_cmd") || continue
                rootfs_chroot_option_set "$t" BOOT_CMD "$boot_cmd" ;;
            config) rootfs_cfg_menu "$t" ;;
            back) return 0 ;;
        esac
    done
}

# Best-effort virtual filesystem setup for chroot operations. Restricted hosts
# such as iSH-AOK may reject one or more mount types; those failures must not
# trip the global ERR trap. The list of mounts created by this invocation is
# returned through ROOTFS_ACTIVE_MOUNTS for precise cleanup.
rootfs_mount_chroot_fs() { # <target>
    local t="$1"
    ROOTFS_ACTIVE_MOUNTS=""
    ROOTFS_DNS_BACKUP=""
    mkdir -p "$t/proc" "$t/sys" "$t/dev" "$t/dev/pts" "$t/etc" || return 1
    if ! mountpoint -q "$t/proc" 2>/dev/null; then
        mount -t proc proc "$t/proc" 2>>"$LOGFILE" && ROOTFS_ACTIVE_MOUNTS="$t/proc $ROOTFS_ACTIVE_MOUNTS" || warn "Could not mount proc in $t"
    fi
    if ! mountpoint -q "$t/sys" 2>/dev/null; then
        mount -t sysfs sysfs "$t/sys" 2>>"$LOGFILE" && ROOTFS_ACTIVE_MOUNTS="$t/sys $ROOTFS_ACTIVE_MOUNTS" || warn "Could not mount sysfs in $t"
    fi
    if ! mountpoint -q "$t/dev" 2>/dev/null; then
        mount --bind /dev "$t/dev" 2>>"$LOGFILE" && ROOTFS_ACTIVE_MOUNTS="$t/dev $ROOTFS_ACTIVE_MOUNTS" || warn "Could not bind-mount /dev in $t"
    fi
    if [ -d /dev/pts ] && ! mountpoint -q "$t/dev/pts" 2>/dev/null; then
        mount --bind /dev/pts "$t/dev/pts" 2>>"$LOGFILE" && ROOTFS_ACTIVE_MOUNTS="$t/dev/pts $ROOTFS_ACTIVE_MOUNTS" || warn "Could not bind-mount /dev/pts in $t"
    fi
    if [ "$(rootfs_chroot_option_get "$t" MOUNT_AOK yes)" = yes ]; then
        if [ -d /AOK ]; then
            mkdir -p "$t/AOK"
            if ! mountpoint -q "$t/AOK" 2>/dev/null; then
                mount --bind /AOK "$t/AOK" 2>>"$LOGFILE" && ROOTFS_ACTIVE_MOUNTS="$t/AOK $ROOTFS_ACTIVE_MOUNTS" || warn "Could not bind-mount /AOK in $t"
            fi
        else
            warn "Mount /AOK is enabled, but /AOK does not exist on the host."
        fi
    fi
    if [ -r /etc/resolv.conf ]; then
        ROOTFS_DNS_BACKUP=$(mktemp -d "${TMPDIR:-/tmp}/systui-dns.XXXXXX" 2>/dev/null || true)
        if [ -n "$ROOTFS_DNS_BACKUP" ]; then
            if [ -L "$t/etc/resolv.conf" ]; then
                readlink "$t/etc/resolv.conf" > "$ROOTFS_DNS_BACKUP/link"
            elif [ -e "$t/etc/resolv.conf" ]; then
                cp -a "$t/etc/resolv.conf" "$ROOTFS_DNS_BACKUP/file" 2>/dev/null || true
            else
                : > "$ROOTFS_DNS_BACKUP/missing"
            fi
        fi
        rm -f "$t/etc/resolv.conf" 2>/dev/null || true
        cp -L /etc/resolv.conf "$t/etc/resolv.conf" 2>>"$LOGFILE" || warn "Could not copy DNS configuration into $t"
    fi
    export ROOTFS_ACTIVE_MOUNTS ROOTFS_DNS_BACKUP
    return 0
}

rootfs_unmount_chroot_fs() { # [mount-list]
    local mounts="${1:-${ROOTFS_ACTIVE_MOUNTS:-}}" m
    for m in $mounts; do
        umount -l "$m" 2>>"$LOGFILE" || true
    done
    ROOTFS_ACTIVE_MOUNTS=""
    if [ -n "${ROOTFS_DNS_BACKUP:-}" ] && [ -d "$ROOTFS_DNS_BACKUP" ]; then
        local t=""
        for m in $mounts; do t=${m%/proc}; t=${t%/sys}; t=${t%/dev/pts}; t=${t%/dev}; [ -d "$t/etc" ] && break; done
        if [ -n "$t" ]; then
            rm -f "$t/etc/resolv.conf" 2>/dev/null || true
            if [ -f "$ROOTFS_DNS_BACKUP/link" ]; then ln -s "$(cat "$ROOTFS_DNS_BACKUP/link")" "$t/etc/resolv.conf" 2>/dev/null || true
            elif [ -e "$ROOTFS_DNS_BACKUP/file" ]; then cp -a "$ROOTFS_DNS_BACKUP/file" "$t/etc/resolv.conf" 2>/dev/null || true
            fi
        fi
        rm -rf "$ROOTFS_DNS_BACKUP"
    fi
    ROOTFS_DNS_BACKUP=""
    export ROOTFS_ACTIVE_MOUNTS ROOTFS_DNS_BACKUP
}

rootfs_qemu_chroot_exec_raw() { # <target> <arch> <command> [args...]
    local t="$1" arch="$2" cmd="$3" qbin; shift 3
    qbin=$(qemu_bin_for "$arch")
    [ -n "$qbin" ] && [ -x "$t/usr/bin/$qbin" ] || return 126
    chroot "$t" "/usr/bin/$qbin" "$cmd" "$@"
}

rootfs_run_second_stage() { # <target> <arch> <use_qemu>
    local t="$1" arch="$2" use_qemu="$3" mounts="" rc=1
    rootfs_mount_chroot_fs "$t" || true
    mounts="${ROOTFS_ACTIVE_MOUNTS:-}"
    if chroot "$t" /debootstrap/debootstrap --second-stage >>"$LOGFILE" 2>&1; then
        rc=0
    elif [ "$use_qemu" = 1 ]; then
        setup_qemu_chroot "$t" "$arch" || { rootfs_unmount_chroot_fs "$mounts"; return 1; }
        if rootfs_qemu_chroot_exec_raw "$t" "$arch" /bin/sh /debootstrap/debootstrap --second-stage >>"$LOGFILE" 2>&1; then
            rc=0
        fi
    fi
    rootfs_unmount_chroot_fs "$mounts"
    return "$rc"
}

rootfs_validate_debootstrap_suite() { # <suite>
    local suite="$1" d="${DEBOOTSTRAP_DIR:-/usr/share/debootstrap}"
    [ -r "$d/scripts/$suite" ] && return 0
    # Some suites are accepted through a script symlink or a vendor-provided
    # script outside the conventional path; debootstrap --print-debs is the
    # authoritative lightweight validation when available.
    debootstrap --print-debs "$suite" 2>>"$LOGFILE" | grep -q .
}

# Run a command inside the rootfs, best effort. Usage: in_chroot <target> <cmd...>
in_chroot() {
    local target="$1"; shift
    rootfs_exec_raw "$target" "$@" 2>>"$LOGFILE"
}

# Discover releases directly from distribution repositories. Falls back to
# maintained defaults when a mirror is unavailable or directory indexing is off.
rootfs_release_candidates() { # <distro> <arch>
    local distro="$1" arch="$2" url="" html="" names=""
    case "$distro" in
        debian) url="http://deb.debian.org/debian/dists/" ;;
        devuan) url="http://deb.devuan.org/merged/dists/" ;;
        ubuntu)
            case "$arch" in arm64|armhf) url="http://ports.ubuntu.com/ubuntu-ports/dists/" ;; *) url="http://archive.ubuntu.com/ubuntu/dists/" ;; esac ;;
        alpine) url="https://dl-cdn.alpinelinux.org/alpine/" ;;
        fedora) url="https://download.fedoraproject.org/pub/fedora/linux/releases/" ;;
        kali) printf '%s\n' kali-rolling kali-last-snapshot; return 0 ;;
        opensuse) url="https://download.opensuse.org/distribution/leap/" ;;
        tumbleweed) printf '%s\n' current; return 0 ;;
        gentoo) printf '%s\n' openrc systemd; return 0 ;;
        arch) printf '%s\n' rolling; return 0 ;;
        void) printf '%s\n' current; return 0 ;;
    esac
    if command -v curl >/dev/null 2>&1; then
        html=$(curl -4 -LfsS --connect-timeout 4 --max-time 10 "$url" 2>/dev/null || true)
    elif command -v wget >/dev/null 2>&1; then
        html=$(wget -4 -qO- -T 10 "$url" 2>/dev/null || true)
    fi
    names=$(printf '%s' "$html" | sed -nE 's/.*href="([^"/]+)\/?".*/\1/p' | sed 's:/$::' | sort -Vu)
    case "$distro" in
        debian) printf '%s\n' "$names" | grep -E '^(stable|testing|unstable|oldstable|bookworm|trixie|forky|sid)$' ;;
        devuan) printf '%s\n' "$names" | grep -E '^(daedalus|excalibur|freia|ceres|stable|testing|unstable)$' ;;
        ubuntu) printf '%s\n' "$names" | grep -E '^[a-z]+$' | grep -Ev '(backports|updates|security|proposed)$' ;;
        alpine) printf '%s\n' "$names" | grep -E '^(v[0-9]+\.[0-9]+|edge)$' ;;
        fedora) printf '%s\n' "$names" | grep -E '^[0-9]+$' ;;
        opensuse) printf '%s\n' "$names" | grep -E '^[0-9]+\.[0-9]+$' ;;
    esac
}

rootfs_release_menu() { # <distro> <arch>
    local distro="$1" arch="$2" candidates="" tags=() r def state
    candidates=$(rootfs_release_candidates "$distro" "$arch" | tail -n 12)
    case "$distro" in
        debian) def=trixie; [ -n "$candidates" ] || candidates=$'bookworm\ntrixie\nforky\nsid' ;;
        devuan) def=excalibur; [ -n "$candidates" ] || candidates=$'daedalus\nexcalibur\nfreia\nceres' ;;
        ubuntu) def=noble; [ -n "$candidates" ] || candidates=$'jammy\nnoble\noracular\nplucky\nquesting' ;;
        alpine) def=v3.20; [ -n "$candidates" ] || candidates=$'v3.19\nv3.20\nv3.21\nedge' ;;
        fedora) def=42; [ -n "$candidates" ] || candidates=$'41\n42\n43' ;;
        kali) def=kali-rolling; candidates=$'kali-rolling\nkali-last-snapshot' ;;
        opensuse) def=15.6; [ -n "$candidates" ] || candidates=$'15.5\n15.6' ;;
        tumbleweed) def=current; candidates=current ;;
        gentoo) def=openrc; candidates=$'openrc\nsystemd' ;;
        arch) def=rolling; candidates=rolling ;;
        void) def=current; candidates=current ;;
    esac
    while IFS= read -r r; do
        [ -n "$r" ] || continue
        state=off; [ "$r" = "$def" ] && state=on
        tags+=("$r" "$distro $r" "$state")
    done <<< "$candidates"
    tags+=(custom "Enter a release manually" off)
    r=$(tui_radio "Rootfs Builder 4/13" "Release from the $distro repository (SPACE selects):" "${tags[@]}") || return 1
    if [ "$r" = custom ]; then
        r=$(tui_input "Custom release" "Release/branch name:" "$def") || return 1
    fi
    [ -n "$r" ] || return 1
    printf '%s\n' "$r"
}


# Interactive additional-package catalogue for RootFS builds.
# Package tags use Debian-style canonical names; map_packages() translates
# known names for Alpine, Arch, Fedora and Void backends.
rootfs_catalog_items() { # category -> lines: tag|description|default
    case "$1" in
        essentials) cat <<'EOF'
bash|Bash shell|on
bash-completion|Bash completion|on
coreutils|GNU core utilities|on
findutils|find, xargs and locate utilities|off
grep|GNU grep|off
sed|GNU sed|off
gawk|GNU awk|off
less|Terminal pager|on
file|File type detection|on
man-db|Manual page database|off
locales|Locale data and generation|off
tzdata|Timezone database|on
ca-certificates|Trusted CA certificates|on
gnupg|OpenPGP tools|off
openssl|TLS and crypto toolkit|off
EOF
            ;;
        shells) cat <<'EOF'
zsh|Z shell|off
fish|Fish shell|off
dash|Small POSIX shell|off
tmux|Terminal multiplexer|off
screen|GNU Screen|off
direnv|Directory environment loader|off
fzf|Fuzzy finder|off
zoxide|Smarter cd command|off
starship|Cross-shell prompt|off
EOF
            ;;
        editors) cat <<'EOF'
nano|Nano editor|on
vim|Vim editor|on
neovim|Neovim editor|off
micro|Micro editor|off
emacs-nox|Emacs terminal build|off
EOF
            ;;
        development) cat <<'EOF'
git|Git version control|on
git-lfs|Git Large File Storage|off
build-essential|Compiler and build essentials|off
cmake|CMake build system|off
ninja-build|Ninja build tool|off
meson|Meson build system|off
pkg-config|Package compiler flags|off
gdb|GNU debugger|off
strace|System-call tracer|off
ltrace|Library-call tracer|off
shellcheck|Shell script analyzer|off
make|GNU Make|off
patch|Patch utility|off
EOF
            ;;
        languages) cat <<'EOF'
python3|Python 3 runtime|on
python3-pip|Python package installer|off
python3-venv|Python virtual environments|off
nodejs|Node.js runtime|off
npm|Node package manager|off
golang|Go toolchain|off
rustc|Rust compiler|off
cargo|Rust package manager|off
ruby|Ruby runtime|off
ruby-dev|Ruby development headers|off
perl|Perl runtime|off
php-cli|PHP command-line runtime|off
openjdk-17-jdk-headless|OpenJDK development kit|off
EOF
            ;;
        network) cat <<'EOF'
iproute2|Modern network configuration tools|on
iputils-ping|Ping utilities|on
net-tools|Legacy ifconfig/netstat tools|off
curl|HTTP transfer client|on
wget|Network downloader|on
rsync|Remote/local file synchronization|off
dnsutils|DNS query tools|off
whois|WHOIS client|off
traceroute|Route tracing utility|off
mtr-tiny|Combined ping and traceroute|off
nmap|Network scanner|off
tcpdump|Packet capture utility|off
netcat-openbsd|TCP/UDP utility|off
socat|Bidirectional data relay|off
iperf3|Network throughput tester|off
ethtool|Ethernet device settings|off
wireless-tools|Legacy wireless utilities|off
wpa-supplicant|Wi-Fi authentication|off
EOF
            ;;
        server) cat <<'EOF'
openssh-client|OpenSSH client|on
openssh-server|OpenSSH server|off
sudo|Privilege delegation|off
cron|Scheduled jobs|off
at|One-time scheduled jobs|off
rsyslog|System logging daemon|off
logrotate|Log rotation|off
chrony|Time synchronization|off
nftables|Firewall framework|off
fail2ban|Login abuse prevention|off
avahi-daemon|mDNS service discovery|off
samba|SMB file sharing|off
nginx|Nginx web server|off
apache2|Apache HTTP server|off
EOF
            ;;
        databases) cat <<'EOF'
sqlite3|SQLite command-line client|off
mariadb-client|MariaDB/MySQL client|off
mariadb-server|MariaDB server|off
postgresql-client|PostgreSQL client|off
postgresql|PostgreSQL server|off
redis-server|Redis server|off
EOF
            ;;
        containers) cat <<'EOF'
podman|Daemonless containers|off
podman-compose|Compose for Podman|off
docker.io|Docker engine|off
docker-compose|Docker Compose|off
containerd|Container runtime|off
runc|OCI runtime|off
skopeo|Container image transport tool|off
buildah|OCI image builder|off
qemu-user-static|Static user-mode emulators|off
EOF
            ;;
        storage) cat <<'EOF'
tar|Tar archive tool|on
unzip|ZIP extraction|on
zip|ZIP creation|off
xz-utils|XZ compression tools|on
zstd|Zstandard compression tools|off
p7zip-full|7-Zip archive support|off
rsync|File synchronization|off
rclone|Cloud storage synchronization|off
parted|Partition editor|off
fdisk|Disk partitioning tools|off
e2fsprogs|ext filesystem tools|off
dosfstools|FAT filesystem tools|off
btrfs-progs|Btrfs filesystem tools|off
xfsprogs|XFS filesystem tools|off
cryptsetup|Disk encryption tools|off
lvm2|Logical Volume Manager|off
mdadm|Software RAID management|off
EOF
            ;;
        monitoring) cat <<'EOF'
procps|Process utilities|on
htop|Interactive process viewer|on
btop|Resource monitor|off
sysstat|Performance statistics|off
iotop|Disk I/O monitor|off
iftop|Network bandwidth monitor|off
nethogs|Per-process network monitor|off
lsof|Open file inspector|off
ncdu|Disk usage browser|off
duf|Modern disk usage display|off
tree|Directory tree display|off
jq|JSON processor|off
lm-sensors|Hardware sensor monitoring|off
smartmontools|Disk health monitoring|off
EOF
            ;;
        security) cat <<'EOF'
lynis|System security auditor|off
rkhunter|Rootkit scanner|off
aide|File integrity monitor|off
clamav|Antivirus scanner|off
apparmor|Application confinement|off
auditd|Linux audit daemon|off
ufw|Simple firewall frontend|off
nmap|Network scanner|off
tcpdump|Packet analyzer|off
openssl|TLS and crypto toolkit|off
gnupg|OpenPGP tools|off
EOF
            ;;
        hardware) cat <<'EOF'
udev|Device manager|off
pciutils|PCI inspection tools|off
usbutils|USB inspection tools|off
lshw|Hardware inventory|off
hwinfo|Hardware detection|off
acpi|ACPI information|off
acpid|ACPI event daemon|off
powertop|Power consumption analyzer|off
cpufrequtils|CPU frequency tools|off
kmod|Kernel module tools|off
EOF
            ;;
        desktop) cat <<'EOF'
dbus|Desktop message bus|off
xorg|X.Org display server|off
xterm|Basic X terminal|off
fonts-dejavu|DejaVu fonts|off
xdg-utils|Desktop integration helpers|off
pulseaudio|PulseAudio sound server|off
pipewire|PipeWire media server|off
EOF
            ;;
        misc) cat <<'EOF'
dialog|Dialog TUI widgets|on
whiptail|Newt TUI widgets|off
expect|Automate interactive programs|off
asciinema|Terminal session recorder|off
cowsay|ASCII speech bubbles|off
figlet|Large ASCII text|off
fortune-mod|Fortune messages|off
EOF
            ;;
    esac
}

rootfs_catalog_select_category() { # category title
    local category="$1" title="$2" tag desc state
    local args=()
    while IFS='|' read -r tag desc state; do
        [ -n "$tag" ] || continue
        args+=("$tag" "$desc" "$state")
    done < <(rootfs_catalog_items "$category")
    [ ${#args[@]} -gt 0 ] || return 0
    tui_check "Additional packages: $title" "SPACE toggles packages; ENTER adds selection:" "${args[@]}"
}

rootfs_catalog_search() {
    local q tag desc state
    q=$(tui_input "Search package catalogue" "Package name or description:" "") || return 0
    [ -n "$q" ] || return 0
    local args=()
    for category in essentials shells editors development languages network server databases containers storage monitoring security hardware desktop misc; do
        while IFS='|' read -r tag desc state; do
            [ -n "$tag" ] || continue
            if printf '%s %s\n' "$tag" "$desc" | grep -qi -- "$q"; then
                args+=("$tag" "$desc" off)
            fi
        done < <(rootfs_catalog_items "$category")
    done
    if [ ${#args[@]} -eq 0 ]; then
        tui_msg "Package catalogue" "No catalogue entries matched: $q"
        return 0
    fi
    tui_check "Package search: $q" "SPACE toggles matches; ENTER adds selection:" "${args[@]}"
}

rootfs_package_catalog() { # distro existing-packages -> final package string
    local distro="$1" selected="$2" choice added manual
    while true; do
        choice=$(tui_menu "Additional package catalogue [$distro]" \
            "Browse categories, add presets, search, or enter native package names.\nCurrently selected: $(printf '%s' "$selected" | xargs -n1 2>/dev/null | sort -u | wc -l) packages" \
            presets "Add a package preset" \
            essentials "Essentials and base utilities" \
            shells "Shells and terminal integration" \
            editors "Editors" \
            development "Development toolchain" \
            languages "Programming languages" \
            network "Networking and diagnostics" \
            server "Server and service tools" \
            databases "Database clients and servers" \
            containers "Containers and virtualization" \
            storage "Storage, filesystems and archives" \
            monitoring "Monitoring and administration" \
            security "Security and auditing" \
            hardware "Hardware utilities" \
            desktop "Desktop/X11 components" \
            misc "Miscellaneous terminal utilities" \
            search "Search the complete catalogue" \
            manual "Enter native package names manually" \
            review "Review selected package names" \
            clear "Clear all additional packages" \
            "done" "Finish package selection") || break
        case "$choice" in
            presets)
                added=$(tui_check "Package presets" "SPACE toggles presets:" \
                    rescue "Recovery tools: shell, editor, network, storage" off \
                    developer "Compiler, Git, Python, debugger and build tools" off \
                    server "SSH, sudo, logging, cron, time sync and firewall" off \
                    network "Network troubleshooting toolkit" off \
                    containers "Podman/Docker and OCI utilities" off \
                    diagnostics "System monitoring and hardware inspection" off) || added=""
                added=${added//\"/}
                case " $added " in *" rescue "*) selected+=" bash nano vim curl wget iproute2 iputils-ping openssh-client rsync tar unzip xz-utils procps htop lsof" ;; esac
                case " $added " in *" developer "*) selected+=" git build-essential make cmake ninja-build meson pkg-config gdb strace python3 python3-pip python3-venv" ;; esac
                case " $added " in *" server "*) selected+=" openssh-server sudo cron rsyslog logrotate chrony nftables fail2ban" ;; esac
                case " $added " in *" network "*) selected+=" curl wget dnsutils whois traceroute mtr-tiny nmap tcpdump netcat-openbsd socat iperf3 ethtool" ;; esac
                case " $added " in *" containers "*) selected+=" podman buildah skopeo runc containerd docker.io docker-compose" ;; esac
                case " $added " in *" diagnostics "*) selected+=" htop btop sysstat iotop iftop nethogs lsof ncdu tree jq pciutils usbutils lshw lm-sensors smartmontools" ;; esac
                ;;
            search) added=$(rootfs_catalog_search) || added=""; selected+=" ${added//\"/}" ;;
            manual) manual=$(tui_input "Native package names" "Space-separated package names for $distro:" "") || manual=""; if [ -n "$manual" ]; then manual=$(rootfs_sanitize_packages "$manual") || { tui_msg "Invalid package" "Package names may not contain shell syntax, paths, whitespace escapes, or leading options."; manual=""; }; fi; selected+=" $manual" ;;
            review)
                local review_text
                review_text=$(printf '%s\n' "$selected" | xargs -n1 2>/dev/null | sed '/^$/d' | sort -u)
                [ -n "$review_text" ] || review_text="No additional packages selected."
                tui_msg "Selected rootfs packages" "$review_text" ;;
            clear) tui_yesno "Clear packages" "Remove every currently selected additional package?" && selected="" ;;
            done) break ;;
            *)
                local title="${choice^}"
                added=$(rootfs_catalog_select_category "$choice" "$title") || added=""
                selected+=" ${added//\"/}"
                ;;
        esac
    done
    # De-duplicate while preserving a stable installation order.
    printf '%s\n' "$selected" | xargs -n1 2>/dev/null | awk 'NF && !seen[$0]++ {printf "%s ", $0}'
}

menu_rootfs() {
    while true; do
        local c
        # Safely capture menu result and handle cancellation (ESC/Cancel)
        if ! c=$(tui_menu "Rootfs" "Mini root filesystems:" \
            build  "Build a new rootfs (guided, 13 stages)" \
            manage "Manage existing rootfs (chroot, inspect, delete...)" \
            back   "Back"); then
            # User pressed ESC/Cancel - gracefully return to parent menu
            return 0
        fi
        
        # Safety check for empty result
        [ -z "$c" ] && return 0
        
        case "$c" in
            build)  rootfs_builder || true ;;
            manage) rootfs_manage || true ;;
            back)   return 0 ;;
            *)      tui_msg "Error" "Unknown option: $c"; continue ;;
        esac
    done
}

rootfs_state_file() { printf '%s/.systui-build-state\n' "$1"; }

rootfs_state_get() { # <target> <key>
    local f key
    f=$(rootfs_state_file "$1"); key="$2"
    [ -r "$f" ] || f="$1/etc/systui-build.conf"
    [ -r "$f" ] || return 1
    sed -nE "s/^${key}=\\\"?([^\\\"]*)\\\"?$/\\1/p" "$f" | tail -n1
}

rootfs_state_escape() { printf '%s' "$1" | tr '\n\r' '  ' | sed 's/["\\]/_/g'; }
rootfs_write_build_state() {
    local target="$1"; shift
    mkdir -p "$target"
    cat > "$(rootfs_state_file "$target")" <<EOF
DISTRO="$(rootfs_state_escape "$1")"
RELEASE="$(rootfs_state_escape "$2")"
ARCH="$(rootfs_state_escape "$3")"
MIRROR="$(rootfs_state_escape "$4")"
PACKAGES="$(rootfs_state_escape "$5")"
USE_QEMU="$(rootfs_state_escape "$6")"
INIT="$(rootfs_state_escape "$7")"
PRESET="$(rootfs_state_escape "$8")"
HOSTNAME="$(rootfs_state_escape "$9")"
POSTCFG="$(rootfs_state_escape "${10}")"
TIMEZONE="$(rootfs_state_escape "${11}")"
BACKEND="$(rootfs_state_escape "${12}")"
STAGE="configured"
EOF
}

rootfs_set_build_stage() { # <target> <stage>
    local f stage
    f=$(rootfs_state_file "$1"); stage="$2"
    [ -e "$f" ] || : > "$f"
    if grep -q '^STAGE=' "$f" 2>/dev/null; then
        sed -i -E "s/^STAGE=.*/STAGE=\"$stage\"/" "$f"
    else
        printf 'STAGE="%s"\n' "$stage" >> "$f"
    fi
}

rootfs_fetch_ubuntu_keyring() {
    local existing=/usr/share/keyrings/ubuntu-archive-keyring.gpg tmp page deb
    [ -r "$existing" ] && { printf '%s\n' "$existing"; return 0; }
    tmp=$(mktemp -d) || return 1
    if command -v apt-get >/dev/null 2>&1; then
        (cd "$tmp" && apt-get -o Acquire::ForceIPv4=true update >/dev/null 2>&1 && apt-get -o Acquire::ForceIPv4=true download ubuntu-keyring >/dev/null 2>&1) || true
    fi
    if ! find "$tmp" -name 'ubuntu-keyring_*.deb' -print -quit | grep -q .; then
        page=$(curl -4 -LfsS --connect-timeout 5 --max-time 20 \
            https://archive.ubuntu.com/ubuntu/pool/main/u/ubuntu-keyring/ 2>/dev/null || true)
        deb=$(printf '%s' "$page" | grep -Eo 'ubuntu-keyring_[^" ]+_all\.deb' | sort -V | tail -n1)
        [ -n "$deb" ] && curl -4 -LfsS -o "$tmp/$deb" \
            "https://archive.ubuntu.com/ubuntu/pool/main/u/ubuntu-keyring/$deb" 2>/dev/null || true
    fi
    deb=$(find "$tmp" -name 'ubuntu-keyring_*.deb' -print -quit)
    [ -n "$deb" ] && command -v dpkg-deb >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }
    dpkg-deb -x "$deb" "$tmp/extract" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }
    [ -r "$tmp/extract/usr/share/keyrings/ubuntu-archive-keyring.gpg" ] || { rm -rf "$tmp"; return 1; }
    mkdir -p /usr/share/keyrings
    cp "$tmp/extract/usr/share/keyrings/ubuntu-archive-keyring.gpg" "$existing" || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    printf '%s\n' "$existing"
}

rootfs_continue_generation() { # <target>
    local t="$1" distro release arch mirror pkgs use_qemu backend stage action
    distro=$(rootfs_state_get "$t" DISTRO || true)
    release=$(rootfs_state_get "$t" RELEASE || true)
    arch=$(rootfs_state_get "$t" ARCH || true)
    mirror=$(rootfs_state_get "$t" MIRROR || true)
    pkgs=$(rootfs_state_get "$t" PACKAGES || true)
    use_qemu=$(rootfs_state_get "$t" USE_QEMU || true)
    backend=$(rootfs_state_get "$t" BACKEND || true)
    stage=$(rootfs_state_get "$t" STAGE || true)

    [ -n "$distro" ] || distro=$(sed -n 's/^ID=//p' "$t/etc/os-release" 2>/dev/null | tr -d '"' | head -n1)
    [ -n "$release" ] || release=$(sed -n 's/^VERSION_CODENAME=//p' "$t/etc/os-release" 2>/dev/null | tr -d '"' | head -n1)
    [ -n "$arch" ] || arch=$(host_debarch)
    [ -n "$use_qemu" ] || { needs_qemu "$arch" && use_qemu=1 || use_qemu=0; }
    backend=$(rootfs_resolve_backend "$distro" "${backend:-auto}" 2>/dev/null || true)

    action=$(tui_check "Continue generation" \
        "Detected: ${distro:-unknown} ${release:-unknown} ($arch), backend: ${backend:-unknown}, stage: ${stage:-unknown}\nSPACE selects recovery steps:" \
        second "Complete interrupted debootstrap second stage" on \
        repair "Repair dpkg/APT package configuration" on \
        packages "Install remaining packages from build state" on \
        config "Open in-rootfs configuration after recovery" on) || return 0
    action=${action//\"/}

    if [ ! -x "$t/bin/sh" ] && [ -n "$distro" ] && [ -n "$release" ] && [ -n "$mirror" ]; then
        case "$distro" in
            debian|devuan|ubuntu|kali)
                tui_yesno "Resume bootstrap" "The base system is incomplete. Re-run ${backend:-the selected backend} into this existing target?" || return 0
                [ -n "$backend" ] || { tui_msg "Backend unavailable" "Install mmdebstrap, debootstrap, cdebootstrap, or multistrap before resuming this build."; return 0; }
                build_debfamily "$distro" "$release" "$arch" "$mirror" "$t" "$pkgs" "$use_qemu" "$backend" || {
                    tui_msg "Resume failed" "Bootstrap recovery failed. See $LOGFILE."; return 0; }
                ;;
            *) tui_msg "Unsupported state" "Automatic pre-bootstrap resume currently supports Debian, Devuan, Ubuntu and Kali roots."; return 0 ;;
        esac
    fi

    case " $action " in *" second "*)
        if [ -x "$t/debootstrap/debootstrap" ]; then
            if run_cmd "Complete debootstrap second stage" rootfs_run_second_stage "$t" "$arch" "$use_qemu"; then
                rootfs_set_build_stage "$t" bootstrap-complete
            else
                rootfs_set_build_stage "$t" bootstrap-second-stage-failed
                return 0
            fi
        fi ;;
    esac
    case " $action " in *" repair "*)
        if [ "$(rootfs_detect_pm "$t")" = apt ]; then
            rootfs_chroot_exec "$t" "Repair package configuration" \
                "export DEBIAN_FRONTEND=noninteractive; dpkg --configure -a; apt-get -f install -y; apt-get update" || true
        fi ;;
    esac
    case " $action " in *" packages "*)
        if [ -n "${pkgs//[[:space:]]/}" ] && [ "$(rootfs_detect_pm "$t")" = apt ]; then
            rootfs_install_deb_packages "$t" "$pkgs" || true
        fi ;;
    esac
    rootfs_set_build_stage "$t" recovered
    case " $action " in *" config "*) rootfs_cfg_menu "$t" ;; esac
    tui_msg "Recovery complete" "Generation recovery finished for:\n$t\n\nReview the log for any package-specific warnings: $LOGFILE"
}

# Entry point kept thin: the build itself runs fail-fast inside run_strict so a
# mid-build failure aborts the build rather than the whole TUI.
rootfs_builder() {
    run_strict "rootfs_builder" rootfs_builder_impl "$@"
}

rootfs_builder_impl() {
    local distro backend release arch mirror target pkgs hostname_v rootpw
    local init_choice init_pkgs="" preset use_qemu=0

    # ---- 1: distro (SPACE selects) ----
    distro=$(tui_radio "Rootfs Builder 1/13" "Distribution (SPACE to select, ENTER to confirm):" \
        debian "Debian" on \
        devuan "Devuan (no systemd)" off \
        ubuntu "Ubuntu" off \
        alpine "Alpine Linux (apk.static)" off \
        arch   "Arch Linux (pacstrap / bootstrap tarball)" off \
        fedora "Fedora (dnf --installroot)" off \
        kali   "Kali Linux (rolling)" off \
        opensuse "openSUSE Leap (zypper --root)" off \
        tumbleweed "openSUSE Tumbleweed (zypper --root)" off \
        gentoo "Gentoo Linux (official stage3)" off \
        void   "Void Linux (official ROOTFS tarball)" off) || return 0
    [ -z "$distro" ] && return

    # ---- 2: bootstrap backend ----
    backend=$(rootfs_backend_menu "$distro") || {
        tui_msg "Backend unavailable" "No usable bootstrap backend was selected for $distro.\n\nInstall the selected tool (for example mmdebstrap, debootstrap, cdebootstrap, qemu-debootstrap, multistrap, pacstrap, dnf, or zypper) and retry."
        return 0
    }
    if ! rootfs_backend_available "$backend"; then
        tui_msg "Missing backend" "The selected backend '$backend' is not available on this host.\n\nInstall its command or required downloader/archive tools, then retry."
        return 0
    fi
    case "$distro" in
        debian|devuan|ubuntu|kali)
            rootfs_backend_config_menu "$distro" "$backend" || return 0
            ;;
    esac

    # ---- 2/3: architecture then release ----
    # Architecture must be selected before Ubuntu release discovery so ARM
    # builds query ports.ubuntu.com rather than the amd64 archive.
    if [ "$distro" = "arch" ]; then
        arch="amd64"
        tui_msg "Architecture" "Arch Linux official repos are x86_64 only.\n(For ARM, see Arch Linux ARM — not covered here.)"
    else
        arch=$(tui_radio "Rootfs Builder 3/13" "Target architecture (SPACE to select):" \
            amd64 "x86_64 / amd64" on \
            arm64 "aarch64 / arm64" off \
            armhf "ARM 32-bit hard-float" off \
            i386  "x86 32-bit" off) || return 0
        [ -z "$arch" ] && return
    fi
    # Per-distro arch labels
    local alpine_arch fedora_arch void_arch
    case "$arch" in
        amd64) alpine_arch="x86_64";  fedora_arch="x86_64";  void_arch="x86_64" ;;
        arm64) alpine_arch="aarch64"; fedora_arch="aarch64"; void_arch="aarch64" ;;
        armhf) alpine_arch="armv7";   fedora_arch="armhfp";  void_arch="armv7l" ;;
        i386)  alpine_arch="x86";     fedora_arch="i386";    void_arch="i686" ;;
    esac

    # ---- release (repository-backed, architecture-aware) ----
    release=$(rootfs_release_menu "$distro" "$arch") || return 0
    if needs_qemu "$arch"; then
        use_qemu=1
        tui_msg "Foreign architecture" \
"Target arch ($arch) differs from the host ($(host_debarch)).

The build will use qemu-user-static + binfmt for any steps that
must run inside the rootfs (debootstrap second stage, passwords,
user creation). Install on the host first if you haven't:

  qemu-user-static  binfmt-support (Debian names)"
    fi

    # ---- 4: init system ----
    case "$distro" in
        debian|ubuntu)
            init_choice=$(tui_radio "Rootfs Builder 5/13" \
                "Init system (SPACE to select).\nsystemd is the distro default; alternatives are swapped in via --include:" \
                systemd  "systemd (distro default)" on \
                sysvinit "SysVinit (sysvinit-core)" off \
                openrc   "OpenRC" off) || return 0
            case "$init_choice" in
                sysvinit)
                    init_pkgs="sysvinit-core sysvinit-utils"
                    [ "$distro" = ubuntu ] && warn "sysvinit-core on Ubuntu is community-maintained and may be missing in some releases."
                    ;;
                openrc)
                    init_pkgs="openrc"
                    warn "OpenRC on $distro still uses sysv-rc scripts underneath; review /etc/rc.conf after first boot."
                    ;;
            esac ;;
        devuan)
            init_choice=$(tui_radio "Rootfs Builder 5/13" \
                "Init system for Devuan (SPACE to select; systemd is not an option here):" \
                sysvinit "SysVinit (Devuan default)" on \
                openrc   "OpenRC" off \
                runit    "runit" off) || return 0
            case "$init_choice" in
                openrc) init_pkgs="openrc" ;;
                runit)  init_pkgs="runit-init" ;;
            esac ;;
        alpine) init_choice="openrc"
                tui_msg "Init system" "Alpine uses OpenRC (included in alpine-base)." ;;
        arch)   init_choice="systemd"
                tui_msg "Init system" "Official Arch Linux is systemd-only.\n(For alternatives on an Arch-like base, see Artix.)" ;;
        fedora|opensuse|tumbleweed) init_choice="systemd"
                tui_msg "Init system" "$distro uses systemd." ;;
        kali)  init_choice="systemd" ;;
        gentoo) init_choice="$release"
                tui_msg "Init system" "Gentoo stage3 flavor selected: $release." ;;
        void)   init_choice="runit"
                tui_msg "Init system" "Void Linux uses runit (included in the base)." ;;
    esac

    # ---- 5: preset and package profiles ----
    preset=$(tui_radio "Rootfs Builder 6/13" "Build preset (SPACE to select):" \
        minimal    "Minimal — base system only" off \
        standard   "Standard — shell, editor, certificates, network tools" on \
        workstation "CLI workstation — standard + productivity and diagnostics" off \
        developer  "Developer — compilers, build systems, Git, Python, debugging" off \
        server     "Server — SSH, sudo, logging, cron, time sync, firewall" off \
        web        "Web server — server + nginx, PHP/Python tools, database clients" off \
        security   "Security/diagnostics — network inspection and audit utilities" off \
        custom     "Custom — select package profiles and individual packages" off) || return 0
    [ -z "$preset" ] && return 0
    case "$preset" in
        minimal) pkgs="" ;;
        standard) pkgs="bash bash-completion nano vim curl wget ca-certificates less file procps iproute2 iputils-ping" ;;
        workstation) pkgs="bash bash-completion nano vim curl wget ca-certificates less file procps iproute2 iputils-ping git tmux screen htop btop rsync unzip zip xz-utils jq tree ncdu" ;;
        developer) pkgs="bash bash-completion nano vim curl wget ca-certificates less file procps iproute2 git build-essential cmake ninja-build meson pkg-config gdb strace python3 python3-pip python3-venv nodejs npm tmux jq" ;;
        server) pkgs="bash nano curl wget ca-certificates less procps iproute2 iputils-ping openssh-server sudo rsyslog cron chrony logrotate htop rsync nftables" ;;
        web) pkgs="bash nano curl wget ca-certificates less procps iproute2 openssh-server sudo rsyslog cron chrony logrotate nginx git python3 python3-pip sqlite3 mariadb-client postgresql-client" ;;
        security) pkgs="bash nano curl wget ca-certificates less procps iproute2 iputils-ping openssh-client nmap tcpdump traceroute mtr-tiny netcat-openbsd socat dnsutils whois gnupg openssl lynis" ;;
        custom)
            local profiles sel
            profiles=$(tui_check "Rootfs package profiles" "Profiles (SPACE toggles):" \
                core "Core CLI utilities" on \
                editors "Editors: nano, vim, neovim" on \
                dev "Build toolchain and debuggers" off \
                languages "Python, Node.js, Go, Rust" off \
                network "Network and DNS utilities" off \
                server "SSH, sudo, cron, logging, time sync" off \
                web "nginx and database clients" off \
                security "Audit and packet diagnostics" off \
                storage "Filesystem, archive and sync tools" off \
                terminal "tmux, htop, btop, jq, tree, ncdu" off) || return 0
            profiles=${profiles//\"/}
            pkgs=""
            case " $profiles " in *" core "*) pkgs+=" bash bash-completion curl wget ca-certificates less file procps iproute2 iputils-ping" ;; esac
            case " $profiles " in *" editors "*) pkgs+=" nano vim neovim" ;; esac
            case " $profiles " in *" dev "*) pkgs+=" git build-essential cmake ninja-build meson pkg-config gdb strace" ;; esac
            case " $profiles " in *" languages "*) pkgs+=" python3 python3-pip python3-venv nodejs npm golang rustc cargo" ;; esac
            case " $profiles " in *" network "*) pkgs+=" nmap tcpdump traceroute mtr-tiny netcat-openbsd socat dnsutils whois" ;; esac
            case " $profiles " in *" server "*) pkgs+=" openssh-server sudo rsyslog cron chrony logrotate nftables" ;; esac
            case " $profiles " in *" web "*) pkgs+=" nginx sqlite3 mariadb-client postgresql-client" ;; esac
            case " $profiles " in *" security "*) pkgs+=" gnupg openssl lynis tcpdump nmap" ;; esac
            case " $profiles " in *" storage "*) pkgs+=" rsync rclone unzip zip xz-utils zstd tar parted e2fsprogs dosfstools" ;; esac
            case " $profiles " in *" terminal "*) pkgs+=" tmux screen htop btop jq tree ncdu" ;; esac
            sel=$(tui_check "Individual packages" "Additional common packages (SPACE toggles):" \
                zsh "Zsh" off fish "Fish" off micro "Micro editor" off \
                git-lfs "Git LFS" off openssh-server "OpenSSH server" off sudo "sudo" off \
                fail2ban "Fail2ban" off avahi-daemon "Avahi/mDNS" off samba "Samba" off \
                ffmpeg "FFmpeg" off imagemagick "ImageMagick" off man-db "Manual pages" off \
                locales "Locales" off tzdata "Timezone database" off) || return 0
            pkgs+=" ${sel//\"/}" ;;
    esac
    # Browse a full, categorized package catalogue for every preset. The
    # selected canonical names are translated by each distro backend where a
    # mapping exists; the manual entry remains available for native names.
    pkgs=$(rootfs_package_catalog "$distro" "$pkgs")
    pkgs="$pkgs $init_pkgs"

    # ---- 6: mirror ----
    local def_mirror
    case "$distro" in
        debian) def_mirror="http://deb.debian.org/debian" ;;
        devuan) def_mirror="http://deb.devuan.org/merged" ;;
        ubuntu)
            if [ "$arch" = "arm64" ] || [ "$arch" = "armhf" ]; then
                def_mirror="https://ports.ubuntu.com/ubuntu-ports"
            else
                def_mirror="https://archive.ubuntu.com/ubuntu"
            fi ;;
        alpine) def_mirror="http://dl-cdn.alpinelinux.org/alpine" ;;
        arch)   def_mirror="https://geo.mirror.pkgbuild.com" ;;
        fedora) def_mirror="https://dl.fedoraproject.org/pub/fedora/linux" ;;
        kali) def_mirror="http://http.kali.org/kali" ;;
        opensuse) def_mirror="https://download.opensuse.org/distribution/leap" ;;
        tumbleweed) def_mirror="https://download.opensuse.org/tumbleweed/repo/oss" ;;
        gentoo) def_mirror="https://distfiles.gentoo.org/releases" ;;
        void)   def_mirror="https://repo-default.voidlinux.org" ;;
    esac
    mirror=$(tui_input "Rootfs Builder 7/13" "Mirror URL:" "$def_mirror") || return 0

    # ---- 7: target directory ----
    target=$(tui_input "Rootfs Builder 8/13" "Target directory for the rootfs:" \
        "$ROOTFS_BASE/${distro}-${release}-${arch}") || return 0
    if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
        tui_msg "Target exists" "$target is not empty.\n\nUse Rootfs > Manage > Continue generation to safely resume it."
        return 0
    fi
    mkdir -p "$target"
    case "$distro" in
        debian|devuan|ubuntu|kali) rootfs_backend_config_write "$target" ;;
    esac

    # ---- 8: identity ----
    hostname_v=$(tui_input "Rootfs Builder 9/13" "Hostname for the rootfs:" "${distro}-mini") || return 0
    rootpw=$(tui_password "Root password" "Root password (blank = locked account):") || return 0

    # ---- 9: optional user account ----
    local mkuser="" userpw="" usersudo=0
    if tui_yesno "Rootfs Builder 10/13" "Create a regular user account inside the rootfs?"; then
        mkuser=$(tui_input "User" "Username:" "user") || mkuser=""
        if [ -n "$mkuser" ]; then
            userpw=$(tui_password "User" "Password for $mkuser (blank = locked):") || userpw=""
            tui_yesno "sudo" "Give $mkuser sudo rights?\n(adds to sudo/wheel group; requires 'sudo' in the package list)" && usersudo=1
            [ $usersudo = 1 ] && case " $pkgs " in *" sudo "*) ;; *) pkgs="$pkgs sudo" ;; esac
        fi
    fi

    # ---- 10: expanded in-rootfs configuration ----
    local postcfg tz="" locale_v="C.UTF-8" shell_v="bash" editor_v="nano" ssh_port="22"
    postcfg=$(tui_check "Rootfs Builder 11/13" "In-rootfs configuration (SPACE toggles):" \
        dns       "Write DNS resolvers" on \
        hosts     "Write hostname and /etc/hosts" on \
        tz        "Set timezone" on \
        locale    "Generate/configure locale" off \
        shell     "Set default shell for root and created user" off \
        editor    "Set default system editor" off \
        sshcfg    "Configure SSH port/authentication" off \
        sshdon    "Enable SSH server at boot" off \
        services  "Enable cron, logging and time synchronization when installed" off \
        mounts    "Create /proc, /sys, /dev and /run mount helper" on \
        machineid "Initialize machine-id when supported" off \
        pkgupdate "Refresh package indexes after build" off \
        upgrade   "Upgrade packages after build" off \
        cleanup   "Clean package caches after build" on \
        manifest  "Write build manifest (/etc/systui-build.conf)" on) || return 0
    postcfg=${postcfg//\"/}
    case " $postcfg " in *" tz "*) tz=$(tui_input "Timezone" "IANA timezone:" "UTC") || tz="UTC" ;; esac
    case " $postcfg " in *" locale "*) locale_v=$(tui_input "Locale" "Locale to generate/configure:" "C.UTF-8") || locale_v="C.UTF-8" ;; esac
    case " $postcfg " in *" shell "*) shell_v=$(tui_radio "Default shell" "Shell (SPACE selects):" bash Bash on zsh Zsh off fish Fish off) || shell_v=bash ;; esac
    case " $postcfg " in *" editor "*) editor_v=$(tui_radio "Default editor" "Editor (SPACE selects):" nano Nano on vim Vim off neovim Neovim off micro Micro off) || editor_v=nano ;; esac
    case " $postcfg " in *" sshcfg "*) ssh_port=$(tui_input "SSH port" "sshd listening port:" "22") || ssh_port=22 ;; esac

    # ---- 11: compression (tar.gz is the default) ----
    local comp
    comp=$(tui_radio "Rootfs Builder 12/13" "Compression format (SPACE to select):" \
        gz   "tar.gz — maximum compatibility (default)" on \
        zst  "tar.zst — faster and usually smaller" off \
        xz   "tar.xz — smallest, slowest" off \
        none "No archive — directory only" off) || return 0

    # ---- 12: confirm ----
    tui_yesno "Rootfs Builder 13/13" \
"Ready to build:

  Distro   : $distro $release ($arch$( [ $use_qemu = 1 ] && echo ', foreign via qemu'))
  Backend  : $backend
  Tool cfg : $(rootfs_backend_config_summary "$backend")
  Init     : $init_choice
  Preset   : $preset
  Mirror   : $mirror
  Target   : $target
  Packages : ${pkgs:-<none>}
  Hostname : $hostname_v
  User     : ${mkuser:-<none>}$( [ $usersudo = 1 ] && echo ' (sudo)')
  Post     : ${postcfg:-<none>} ${tz:+tz=$tz}
  Archive  : $comp

Proceed?" || return 0

    rootfs_write_build_state "$target" \
        "$distro" "$release" "$arch" "$mirror" "$pkgs" "$use_qemu" \
        "$init_choice" "$preset" "$hostname_v" "$postcfg" "$tz" "$backend"

    case "$distro" in
        debian|devuan|ubuntu|kali) build_debfamily "$distro" "$release" "$arch" "$mirror" "$target" "$pkgs" "$use_qemu" "$backend" ;;
        alpine)               build_alpine "$release" "$alpine_arch" "$mirror" "$target" "$pkgs" ;;
        arch)                 build_arch "$mirror" "$target" "$pkgs" "$backend" ;;
        fedora)               build_fedora "$release" "$fedora_arch" "$mirror" "$target" "$pkgs" ;;
        opensuse|tumbleweed)  build_opensuse "$distro" "$release" "$arch" "$mirror" "$target" "$pkgs" ;;
        gentoo)               build_gentoo "$release" "$arch" "$mirror" "$target" "$pkgs" ;;
        void)                 build_void "$void_arch" "$mirror" "$target" "$pkgs" "$use_qemu" ;;
    esac || { tui_msg "Build failed" "Bootstrap step failed. See $LOGFILE."; show_warnings; return 0; }

    rootfs_postconfig "$target" "$distro" "$release" "$arch" "$init_choice" "$preset" \
        "$hostname_v" "$rootpw" "$mkuser" "$userpw" "$usersudo" "$postcfg" "$tz" "$pkgs" "$use_qemu" \
        "$locale_v" "$shell_v" "$editor_v" "$ssh_port" \
        || { rootfs_set_build_stage "$target" postconfig-failed; tui_msg "Configuration failed" "The base rootfs was created, but required post-configuration failed. Review $LOGFILE."; return 0; }

    if ! rootfs_validate_integrity "$target"; then
        rootfs_set_build_stage "$target" validation-failed
        tui_msg "Validation failed" "The rootfs did not pass final integrity checks. Review $LOGFILE."
        return 0
    fi
    rootfs_set_build_stage "$target" complete
    show_warnings

    # ---- archive ----
    if [ "$comp" != none ]; then
        local ext
        case "$comp" in
            zst) ext="tar.zst" ;;
            gz)  ext="tar.gz" ;;
            xz)  ext="tar.xz" ;;
        esac
        local archive="${target%/}.$ext"
        if [ "$comp" = zst ] && ! command -v zstd >/dev/null; then
            warn "zstd not installed — skipping compression."
            show_warnings
        else
            case "$comp" in
                gz)  run_cmd "Compressing rootfs -> $archive" tar -C "$target" --numeric-owner -czf "$archive" . ;;
                xz)  run_cmd "Compressing rootfs -> $archive" tar -C "$target" --numeric-owner -cJf "$archive" . ;;
                zst) run_cmd "Compressing rootfs -> $archive" tar --zstd -C "$target" --numeric-owner -cf "$archive" . ;;
            esac && tui_msg "Done" "Archive written:\n$archive"
        fi
    fi

    tui_msg "Rootfs complete" "Rootfs built at:\n$target\nInit: $init_choice\n\nEnter it via Rootfs -> Manage (mounts /proc,/sys,/dev),\nor manually: chroot $target /bin/sh"
}

# ---- Post-build configuration inside the rootfs -----------------------------
rootfs_postconfig() {
    local target="$1" distro="$2" release="$3" arch="$4" init_choice="$5" preset="$6"
    local hostname_v="$7" rootpw="$8" mkuser="$9" userpw="${10}" usersudo="${11}"
    local postcfg="${12}" tz="${13}" pkgs="${14}" use_qemu="${15}"
    local locale_v="${16:-C.UTF-8}" shell_v="${17:-bash}" editor_v="${18:-nano}" ssh_port="${19:-22}"
    rootfs_valid_hostname "$hostname_v" || { warn "Invalid hostname: $hostname_v"; return 1; }
    [ -z "$mkuser" ] || rootfs_valid_username "$mkuser" || { warn "Invalid username: $mkuser"; return 1; }
    rootfs_valid_port "$ssh_port" || { warn "Invalid SSH port: $ssh_port"; return 1; }
    rootfs_valid_locale "$locale_v" || { warn "Invalid locale: $locale_v"; return 1; }
    [ -z "$tz" ] || rootfs_valid_timezone "$tz" || { warn "Invalid timezone: $tz"; return 1; }
    pkgs=$(rootfs_sanitize_packages "$pkgs") || return 1

    echo "$hostname_v" > "$target/etc/hostname"

    [ "$use_qemu" = 1 ] && setup_qemu_chroot "$target" "$arch"

    local can_chroot=1
    [ -x "$target/bin/sh" ] || can_chroot=0
    if [ "$use_qemu" = 1 ] && ! [ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ] \
        && ! [ -e /proc/sys/fs/binfmt_misc/qemu-arm ]; then
        # binfmt entries vary by distro registration; only warn, still try.
        warn "qemu binfmt registration not detected — chroot steps may fail."
    fi

    # root password
    if [ -n "$rootpw" ] && [ $can_chroot = 1 ]; then
        echo "root:$rootpw" | in_chroot "$target" chpasswd \
            || warn "Could not set root password in chroot."
    fi

    # user account
    if [ -n "$mkuser" ] && [ $can_chroot = 1 ]; then
        if in_chroot "$target" sh -c "command -v useradd" >/dev/null; then
            in_chroot "$target" useradd -m -s /bin/sh "$mkuser" || warn "useradd $mkuser failed in chroot."
        else
            in_chroot "$target" adduser -D "$mkuser" || warn "adduser $mkuser failed in chroot."
        fi
        [ -n "$userpw" ] && { echo "$mkuser:$userpw" | in_chroot "$target" chpasswd \
            || warn "Could not set password for $mkuser."; }
        if [ "$usersudo" = 1 ]; then
            in_chroot "$target" sh -c "getent group sudo >/dev/null && adduser $mkuser sudo 2>/dev/null || usermod -aG sudo $mkuser 2>/dev/null || addgroup $mkuser wheel 2>/dev/null || usermod -aG wheel $mkuser 2>/dev/null" \
                || warn "Could not add $mkuser to sudo/wheel group."
        fi
    fi

    # post-config checklist items
    case " $postcfg " in *" dns "*)
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$target/etc/resolv.conf" ;;
    esac
    case " $postcfg " in *" hosts "*)
        printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n::1\t\tlocalhost ip6-localhost\n' "$hostname_v" \
            > "$target/etc/hosts" ;;
    esac
    if [ -n "$tz" ]; then
        if [ -f "$target/usr/share/zoneinfo/$tz" ]; then
            ln -sf "/usr/share/zoneinfo/$tz" "$target/etc/localtime"
            echo "$tz" > "$target/etc/timezone" 2>/dev/null
        else
            warn "Timezone data for '$tz' not present in rootfs (install tzdata inside it)."
        fi
    fi
    case " $postcfg " in *" sshdon "*)
        case " $pkgs " in
            *" openssh-server "*|*" openssh "*)
                case "$init_choice" in
                    systemd)
                        in_chroot "$target" systemctl enable ssh 2>/dev/null \
                            || in_chroot "$target" systemctl enable sshd 2>/dev/null \
                            || warn "Could not enable sshd via systemctl in rootfs." ;;
                    openrc)
                        in_chroot "$target" rc-update add sshd default 2>/dev/null \
                            || warn "Could not rc-update sshd in rootfs." ;;
                    runit)
                        mkdir -p "$target/etc/runit/runsvdir/default" 2>/dev/null
                        if [ -d "$target/etc/sv/sshd" ]; then
                            ln -sf /etc/sv/sshd "$target/etc/runit/runsvdir/default/" 2>/dev/null
                        else
                            warn "No runit sshd service dir in rootfs — enable manually."
                        fi ;;
                    sysvinit)
                        in_chroot "$target" update-rc.d ssh defaults 2>/dev/null \
                            || warn "Could not update-rc.d ssh in rootfs." ;;
                esac ;;
            *) warn "sshd enable requested but openssh-server wasn't in the package list." ;;
        esac ;;
    esac
    case " $postcfg " in *" services "*)
        case "$init_choice" in
            systemd) for svc in cron crond rsyslog chrony chronyd; do in_chroot "$target" systemctl enable "$svc" >/dev/null 2>&1 || true; done ;;
            openrc) for svc in crond syslog chronyd; do in_chroot "$target" rc-update add "$svc" default >/dev/null 2>&1 || true; done ;;
            sysvinit) for svc in cron rsyslog chrony; do in_chroot "$target" update-rc.d "$svc" defaults >/dev/null 2>&1 || true; done ;;
            runit) for svc in cron crond rsyslog chronyd; do [ -d "$target/etc/sv/$svc" ] && ln -sfn "/etc/sv/$svc" "$target/etc/runit/runsvdir/default/$svc"; done ;;
        esac ;;
    esac
    case " $postcfg " in *" manifest "*)
        cat > "$target/etc/systui-build.conf" <<EOF
# Generated by systui $VERSION
BUILD_DATE="$(date '+%F %T')"
DISTRO="$distro"
RELEASE="$release"
ARCH="$arch"
BACKEND="$(rootfs_state_get "$target" BACKEND 2>/dev/null || echo unknown)"
INIT="$init_choice"
PRESET="$preset"
PACKAGES="$pkgs"
HOSTNAME="$hostname_v"
EOF
        ;;
    esac

    # Expanded post-build policies. All commands are best-effort for portability.
    local pmcmd=""
    case "$distro" in debian|devuan|ubuntu|kali) pmcmd=apt ;; alpine) pmcmd=apk ;; arch) pmcmd=pacman ;; fedora) pmcmd=dnf ;; opensuse|tumbleweed) pmcmd=zypper ;; gentoo) pmcmd=emerge ;; void) pmcmd=xbps ;; esac
    case " $postcfg " in *" locale "*)
        case "$pmcmd" in
            apt) [ -f "$target/etc/locale.gen" ] && { grep -qF "$locale_v UTF-8" "$target/etc/locale.gen" || echo "$locale_v UTF-8" >> "$target/etc/locale.gen"; }; in_chroot "$target" sh -c "command -v locale-gen >/dev/null && locale-gen || true" ;;
            apk) printf 'LANG=%s\n' "$locale_v" > "$target/etc/profile.d/locale.sh" ;;
            *) printf 'LANG=%s\n' "$locale_v" > "$target/etc/locale.conf" ;;
        esac ;; esac
    case " $postcfg " in *" shell "*)
        local shell_path="/bin/$shell_v"; [ "$shell_v" = fish ] && shell_path=/usr/bin/fish
        [ -x "$target$shell_path" ] && { in_chroot "$target" chsh -s "$shell_path" root || true; [ -n "$mkuser" ] && in_chroot "$target" chsh -s "$shell_path" "$mkuser" || true; } ;; esac
    case " $postcfg " in *" editor "*)
        printf 'export EDITOR=%s\nexport VISUAL=%s\n' "$editor_v" "$editor_v" > "$target/etc/profile.d/editor.sh"
        chmod 644 "$target/etc/profile.d/editor.sh" ;; esac
    case " $postcfg " in *" sshcfg "*)
        if [ -f "$target/etc/ssh/sshd_config" ]; then
            sed -i -E "s/^#?Port .*/Port $ssh_port/; s/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/; s/^#?PasswordAuthentication .*/PasswordAuthentication yes/" "$target/etc/ssh/sshd_config"
        fi ;; esac
    case " $postcfg " in *" mounts "*)
        mkdir -p "$target/usr/local/sbin"
        cat > "$target/usr/local/sbin/mount-rootfs-virtualfs" <<'EOF'
#!/bin/sh
mountpoint -q /proc || mount -t proc proc /proc
mountpoint -q /sys || mount -t sysfs sysfs /sys
mountpoint -q /dev || mount --rbind /dev /dev
mkdir -p /run /dev/pts
mountpoint -q /dev/pts || mount -t devpts devpts /dev/pts
EOF
        chmod +x "$target/usr/local/sbin/mount-rootfs-virtualfs" ;; esac
    case " $postcfg " in *" machineid "*)
        : > "$target/etc/machine-id"; in_chroot "$target" sh -c 'command -v systemd-machine-id-setup >/dev/null && systemd-machine-id-setup || true' ;; esac
    case " $postcfg " in *" pkgupdate "*)
        case "$pmcmd" in apt) in_chroot "$target" apt-get update ;; apk) in_chroot "$target" apk update ;; pacman) in_chroot "$target" pacman -Sy --noconfirm ;; dnf) in_chroot "$target" dnf makecache ;; zypper) in_chroot "$target" zypper --non-interactive refresh ;; emerge) in_chroot "$target" emerge --sync ;; xbps) in_chroot "$target" xbps-install -S ;; esac || true ;; esac
    case " $postcfg " in *" upgrade "*)
        case "$pmcmd" in apt) in_chroot "$target" apt-get upgrade -y ;; apk) in_chroot "$target" apk upgrade ;; pacman) in_chroot "$target" pacman -Syu --noconfirm ;; dnf) in_chroot "$target" dnf upgrade -y ;; zypper) in_chroot "$target" zypper --non-interactive update ;; emerge) in_chroot "$target" emerge -uDN @world ;; xbps) in_chroot "$target" xbps-install -yu ;; esac || true ;; esac
    case " $postcfg " in *" cleanup "*)
        case "$pmcmd" in apt) in_chroot "$target" sh -c 'apt-get clean; rm -rf /var/lib/apt/lists/*' ;; apk) rm -rf "$target/var/cache/apk"/* ;; pacman) rm -rf "$target/var/cache/pacman/pkg"/* ;; dnf) in_chroot "$target" dnf clean all ;; zypper) in_chroot "$target" zypper clean --all ;; emerge) rm -rf "$target/var/cache/distfiles"/* ;; xbps) rm -rf "$target/var/cache/xbps"/* ;; esac || true ;; esac

}

# ---- Per-distro bootstrap backends ------------------------------------------

# Test a repository path over IPv4. iSH-AOK environments may expose IPv6
# DNS records even when no usable IPv6 route exists, producing "No route to host".
rootfs_probe_deb_mirror() { # mirror release
    local mirror release probe
    mirror="${1%/}"
    release="$2"
    probe="$mirror/dists/$release/InRelease"
    if command -v curl >/dev/null 2>&1; then
        curl -4 -LfsS --connect-timeout 8 --max-time 20 --range 0-1023 "$probe" -o /dev/null 2>>"$LOGFILE"
    elif command -v wget >/dev/null 2>&1; then
        wget -4 -q --spider --timeout=20 --tries=1 "$probe" 2>>"$LOGFILE"
    else
        return 2
    fi
}

# Select a reachable Ubuntu endpoint. The selected architecture determines
# whether the regular archive or Ubuntu Ports archive is valid.
rootfs_select_ubuntu_mirror() { # requested arch release
    local requested="${1%/}" arch="$2" release="$3" candidate
    local candidates=()
    [ -n "$requested" ] && candidates+=("$requested")
    case "$arch" in
        arm64|armhf)
            candidates+=(
                "https://ports.ubuntu.com/ubuntu-ports"
                "http://ports.ubuntu.com/ubuntu-ports"
            ) ;;
        *)
            candidates+=(
                "https://archive.ubuntu.com/ubuntu"
                "https://us.archive.ubuntu.com/ubuntu"
                "http://archive.ubuntu.com/ubuntu"
                "http://us.archive.ubuntu.com/ubuntu"
            ) ;;
    esac
    local seen=" "
    for candidate in "${candidates[@]}"; do
        candidate=${candidate%/}
        case "$seen" in *" $candidate "*) continue ;; esac
        seen+="$candidate "
        log "rootfs: probing Ubuntu mirror over IPv4: $candidate"
        if rootfs_probe_deb_mirror "$candidate" "$release"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

# Create a temporary wget configuration that prevents debootstrap's downloader
# from choosing an unusable IPv6 route. GNU wget reads this through WGETRC.
rootfs_ipv4_wgetrc() {
    local f
    f=$(mktemp "${TMPDIR:-/tmp}/systui-wgetrc.XXXXXX") || return 1
    cat >"$f" <<'EOF'
inet4_only = on
timeout = 30
tries = 3
retry_connrefused = on
EOF
    printf '%s\n' "$f"
}

rootfs_prepare_ubuntu_apt() { # target release arch mirror
    local target="$1" release="$2" arch="$3" mirror="${4%/}"
    mkdir -p "$target/etc/apt/apt.conf.d" "$target/etc/apt/sources.list.d"
    cat >"$target/etc/apt/apt.conf.d/99systui-force-ipv4" <<'EOF'
// iSH-AOK may resolve IPv6 addresses without providing an IPv6 route.
Acquire::ForceIPv4 "true";
Acquire::Retries "3";
Dpkg::Use-Pty "0";
EOF
    # Ensure selected catalogue packages from universe/multiverse are visible.
    # Keep initial package installation on the base pocket. Update/security
    # pockets can be enabled later and may not exist for development/EOL suites.
    cat >"$target/etc/apt/sources.list" <<EOF
deb $mirror $release main restricted universe multiverse
EOF
}

rootfs_install_deb_packages() { # target "space separated packages"
    local target pkgs script
    target="$1"
    pkgs="$2"
    script="$target/tmp/systui-install-packages.sh"
    [ -n "${pkgs//[[:space:]]/}" ] || return 0
    mkdir -p "$target/tmp" "$target/usr/sbin"
    cat >"$target/usr/sbin/policy-rc.d" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 755 "$target/usr/sbin/policy-rc.d"
    cat >"$script" <<'EOF'
#!/bin/sh
set -eu
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
apt-get -o Acquire::ForceIPv4=true update
available=""
skipped=""
for pkg in "$@"; do
    [ -n "$pkg" ] || continue
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        available="$available $pkg"
    else
        skipped="$skipped $pkg"
    fi
done
if [ -n "$skipped" ]; then
    printf '%s\n' "$skipped" > /var/log/systui-skipped-packages.log
fi
if [ -n "$available" ]; then
    apt-get -o Acquire::ForceIPv4=true \
        -o Dpkg::Options::=--force-confold \
        --no-install-recommends install -y $available
fi
dpkg --configure -a
apt-get -f install -y
EOF
    chmod 755 "$script"
    pkgs=$(rootfs_sanitize_packages "$pkgs") || return 1
    local pkg_args=() pkg
    for pkg in $pkgs; do pkg_args+=("$pkg"); done
    rootfs_chroot_exec_args "$target" "Install selected Debian-family packages" \
        /tmp/systui-install-packages.sh "${pkg_args[@]}"
    local rc=$?
    rm -f "$script" "$target/usr/sbin/policy-rc.d"
    if [ -s "$target/var/log/systui-skipped-packages.log" ]; then
        warn "Some packages are unavailable for this release/architecture: $(xargs < "$target/var/log/systui-skipped-packages.log")"
    fi
    return $rc
}

build_debfamily() { # distro release arch mirror target pkgs use_qemu backend
    local distro="$1" release="$2" arch="$3" mirror="$4" target="$5" pkgs="$6" use_qemu="$7"
    local backend="${8:-debootstrap}" wgetrc="" selected_mirror=""

    # Derive foreign/native mode from the actual host and target architectures.
    # Native Ubuntu builds must use plain debootstrap. QEMU is only introduced
    # for a genuinely foreign target architecture.
    if needs_qemu "$arch"; then
        use_qemu=1
    else
        use_qemu=0
    fi
    rootfs_backend_config_load "$target" "$distro" "$backend"
    case "$backend" in
        debootstrap|qemu-debootstrap)
            command -v "$backend" >/dev/null 2>&1 || {
                tui_msg "Missing tool" "$backend is required for the selected backend.\nInstall it with the host package manager and retry."
                return 1
            }
            # qemu-debootstrap delegates suite handling to debootstrap.
            command -v debootstrap >/dev/null 2>&1 || {
                tui_msg "Missing tool" "debootstrap is required for the selected backend.\nInstall debootstrap with the host package manager and retry."
                return 1
            }
            if ! rootfs_validate_debootstrap_suite "$release"; then
                tui_msg "Unsupported release" "The installed debootstrap does not support suite '$release'.\n\nUpdate debootstrap, select mmdebstrap, or choose a supported release."
                rootfs_set_build_stage "$target" unsupported-release
                return 1
            fi
            ;;
        mmdebstrap)
            command -v mmdebstrap >/dev/null 2>&1 || {
                tui_msg "Missing tool" "mmdebstrap is required for the selected backend.\nInstall mmdebstrap with the host package manager and retry."
                return 1
            }
            ;;
        cdebootstrap|multistrap)
            command -v "$backend" >/dev/null 2>&1 || {
                tui_msg "Missing tool" "$backend is required for the selected backend.\nInstall it with the host package manager and retry."
                return 1
            }
            ;;
        *)
            tui_msg "Unsupported backend" "'$backend' cannot build a Debian-family rootfs."
            return 1
            ;;
    esac

    if [ "$distro" = ubuntu ]; then
        selected_mirror=$(rootfs_select_ubuntu_mirror "$mirror" "$arch" "$release" 2>/dev/null || true)
        if [ -z "$selected_mirror" ]; then
            tui_msg "Ubuntu mirror unreachable" "No Ubuntu mirror could be reached over IPv4 for $release/$arch.

Check that iSH-AOK has network access and DNS resolution, then retry. The builder tested the selected mirror plus Ubuntu's official fallback endpoints."
            return 1
        fi
        [ "$selected_mirror" = "$mirror" ] || log "rootfs: using reachable Ubuntu fallback mirror $selected_mirror"
        mirror="$selected_mirror"
    elif ! rootfs_probe_deb_mirror "$mirror" "$release"; then
        tui_msg "Repository unreachable" "The repository preflight failed for:\n$mirror/dists/$release/InRelease\n\nCheck the mirror, release name, DNS, and network connectivity."
        rootfs_set_build_stage "$target" mirror-preflight-failed
        return 1
    fi

    wgetrc=$(rootfs_ipv4_wgetrc 2>/dev/null || true)

    # Use the matching archive keyring when available. This is especially
    # important when building Ubuntu from a Debian/Devuan host.
    local keyring="" keyring_pkg=""
    case "$distro" in
        debian)
            keyring_pkg="debian-archive-keyring"
            [ -r /usr/share/keyrings/debian-archive-keyring.gpg ] && keyring=/usr/share/keyrings/debian-archive-keyring.gpg
            ;;
        devuan)
            keyring_pkg="devuan-keyring"
            for k in /usr/share/keyrings/devuan-archive-keyring.gpg /usr/share/keyrings/devuan-keyring.gpg; do
                [ -r "$k" ] && { keyring="$k"; break; }
            done
            ;;
        ubuntu)
            keyring_pkg="ubuntu-keyring"
            [ -r /usr/share/keyrings/ubuntu-archive-keyring.gpg ] && keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg
            ;;
        kali)
            keyring_pkg="kali-archive-keyring"
            [ -r /usr/share/keyrings/kali-archive-keyring.gpg ] && keyring=/usr/share/keyrings/kali-archive-keyring.gpg
            ;;
    esac

    if [ "$ROOTFS_BACKEND_KEYRING_MODE" = custom ]; then
        [ -r "$ROOTFS_BACKEND_KEYRING_PATH" ] || {
            tui_msg "Keyring unavailable" "The configured keyring is not readable:\n$ROOTFS_BACKEND_KEYRING_PATH"
            return 1
        }
        keyring="$ROOTFS_BACKEND_KEYRING_PATH"
    fi

    if [ -z "$keyring" ] && [ -n "$keyring_pkg" ] && command -v apt-get >/dev/null 2>&1; then
        log "rootfs: attempting to install missing keyring package $keyring_pkg"
        DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::ForceIPv4=true update >>"$LOGFILE" 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::ForceIPv4=true install -y --no-install-recommends "$keyring_pkg" >>"$LOGFILE" 2>&1 || true
        case "$distro" in
            debian) [ -r /usr/share/keyrings/debian-archive-keyring.gpg ] && keyring=/usr/share/keyrings/debian-archive-keyring.gpg ;;
            devuan)
                for k in /usr/share/keyrings/devuan-archive-keyring.gpg /usr/share/keyrings/devuan-keyring.gpg; do
                    [ -r "$k" ] && { keyring="$k"; break; }
                done ;;
            ubuntu) [ -r /usr/share/keyrings/ubuntu-archive-keyring.gpg ] && keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg ;;
            kali) [ -r /usr/share/keyrings/kali-archive-keyring.gpg ] && keyring=/usr/share/keyrings/kali-archive-keyring.gpg ;;
        esac
    fi

    if [ "$distro" = ubuntu ] && [ -z "$keyring" ]; then
        keyring=$(rootfs_fetch_ubuntu_keyring 2>/dev/null || true)
    fi
    if [ "$distro" = ubuntu ] && [ -z "$keyring" ] \
        && ! { [ "$backend" = cdebootstrap ] && [ "$ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH" = yes ]; } \
        && ! { [ "$backend" = multistrap ] && [ -n "$ROOTFS_MULTISTRAP_CONFIG" ]; }; then
        tui_msg "Ubuntu keyring missing" \
"Ubuntu rootfs verification requires ubuntu-archive-keyring.gpg.

Install ubuntu-keyring on the host or use System Configuration > Packages > Repos > Keys, then retry."
        return 1
    fi

    local opts=(--arch="$arch") csv_include="${ROOTFS_BACKEND_INCLUDE// /,}" csv_exclude="${ROOTFS_BACKEND_EXCLUDE// /,}"
    [ "$ROOTFS_BACKEND_VARIANT" = default ] || opts+=(--variant="$ROOTFS_BACKEND_VARIANT")
    [ -n "$ROOTFS_BACKEND_COMPONENTS" ] && opts+=(--components="$ROOTFS_BACKEND_COMPONENTS")
    [ -n "$csv_include" ] && opts+=(--include="$csv_include")
    [ -n "$csv_exclude" ] && opts+=(--exclude="$csv_exclude")
    case "$ROOTFS_BACKEND_MERGED" in yes) opts+=(--merged-usr);; no) opts+=(--no-merged-usr);; esac
    [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && opts+=(--verbose)
    [ -n "$keyring" ] && opts+=(--keyring="$keyring")

    # Additional packages are intentionally not passed through --include.
    # A missing optional package or failing maintainer script must not destroy
    # an otherwise valid base rootfs. Extras are installed after bootstrap.
    if [ "$backend" = mmdebstrap ]; then
        local mmopts=(--mode="$ROOTFS_MMDEBSTRAP_MODE" --format=directory --variant="$ROOTFS_BACKEND_VARIANT" --architectures="$arch" --skip=check/empty)
        [ -n "$ROOTFS_BACKEND_COMPONENTS" ] && mmopts+=(--components="$ROOTFS_BACKEND_COMPONENTS")
        [ -n "$keyring" ] && mmopts+=(--keyring="$keyring")
        local mm_include="$ROOTFS_BACKEND_INCLUDE" p
        for p in $ROOTFS_BACKEND_EXCLUDE; do mm_include+=" ${p}-"; done
        [ -n "${mm_include//[[:space:]]/}" ] && mmopts+=(--include="${mm_include# }")
        if [ "$ROOTFS_MMDEBSTRAP_PRUNE" = yes ]; then
            mmopts+=(
                --dpkgopt='path-exclude=/usr/share/man/*'
                --dpkgopt='path-exclude=/usr/share/locale/*'
                --dpkgopt='path-include=/usr/share/locale/locale.alias'
                --dpkgopt='path-exclude=/usr/share/doc/*'
                --dpkgopt='path-include=/usr/share/doc/*/copyright'
            )
        fi
        [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && mmopts+=(--verbose)
        rootfs_set_build_stage "$target" bootstrap
        run_cmd "mmdebstrap $distro/$release ($arch)" \
            env DEBIAN_FRONTEND=noninteractive \
            mmdebstrap "${mmopts[@]}" "$release" "$target" "$mirror" || return 1
        rootfs_set_build_stage "$target" bootstrap-complete
    elif [ "$backend" = qemu-debootstrap ]; then
        rootfs_set_build_stage "$target" bootstrap
        run_cmd "qemu-debootstrap $distro/$release ($arch)" \
            env ${wgetrc:+WGETRC="$wgetrc"} DEBOOTSTRAP_DOWNLOAD_RETRIES=3 \
            qemu-debootstrap "${opts[@]}" "$release" "$target" "$mirror" || { rm -f "$wgetrc"; return 1; }
        rootfs_set_build_stage "$target" bootstrap-complete
    elif [ "$backend" = cdebootstrap ]; then
        local cdopts=(--arch="$arch" --flavour="$ROOTFS_BACKEND_VARIANT")
        [ -n "$csv_include" ] && cdopts+=(--include="$csv_include")
        [ -n "$csv_exclude" ] && cdopts+=(--exclude="$csv_exclude")
        [ -n "$keyring" ] && cdopts+=(--keyring="$keyring")
        [ -n "$ROOTFS_CDEBOOTSTRAP_CONFIGDIR" ] && cdopts+=(--configdir="$ROOTFS_CDEBOOTSTRAP_CONFIGDIR")
        [ "$ROOTFS_CDEBOOTSTRAP_ALLOW_UNAUTH" = yes ] && cdopts+=(--allow-unauthenticated)
        [ "$ROOTFS_BACKEND_VERBOSE" = yes ] && cdopts+=(--verbose)
        [ "$use_qemu" = 1 ] && cdopts+=(--foreign)
        rootfs_set_build_stage "$target" bootstrap
        run_cmd "cdebootstrap $distro/$release ($arch)" \
            cdebootstrap "${cdopts[@]}" "$release" "$target" "$mirror" || return 1
        if [ "$use_qemu" = 1 ]; then setup_qemu_chroot "$target" "$arch" || return 1; fi
        rootfs_chroot_exec "$target" "Configure cdebootstrap packages" \
            'export DEBIAN_FRONTEND=noninteractive; dpkg --configure -a' || return 1
        rootfs_set_build_stage "$target" bootstrap-complete
    elif [ "$backend" = multistrap ]; then
        local msconf="" mspkg="$ROOTFS_MULTISTRAP_KEYRING_PACKAGE"
        if [ -n "$ROOTFS_MULTISTRAP_CONFIG" ]; then
            msconf="$ROOTFS_MULTISTRAP_CONFIG"
        else
            msconf=$(mktemp "${TMPDIR:-/tmp}/systui-multistrap.XXXXXX.conf") || return 1
            [ -n "$mspkg" ] || mspkg="$keyring_pkg"
            rootfs_multistrap_config_write "$msconf" "$arch" "$target" "$mirror" "$release" \
                "$ROOTFS_BACKEND_COMPONENTS" "$ROOTFS_BACKEND_INCLUDE" "$mspkg"
        fi
        rootfs_set_build_stage "$target" bootstrap
        run_cmd "multistrap $distro/$release ($arch)" multistrap -a "$arch" -d "$target" -f "$msconf" || {
            [ "$msconf" = "$ROOTFS_MULTISTRAP_CONFIG" ] || rm -f "$msconf"
            return 1
        }
        [ "$msconf" = "$ROOTFS_MULTISTRAP_CONFIG" ] || rm -f "$msconf"
        if [ "$use_qemu" = 1 ]; then setup_qemu_chroot "$target" "$arch" || return 1; fi
        rootfs_chroot_exec "$target" "Configure multistrap packages" \
            'export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C; dpkg --configure -a' || return 1
        rootfs_set_build_stage "$target" bootstrap-complete
    elif [ "$use_qemu" = 1 ]; then
        opts+=(--foreign)
        rootfs_set_build_stage "$target" bootstrap-first-stage
        run_cmd "debootstrap --foreign $distro/$release ($arch)" \
            env ${wgetrc:+WGETRC="$wgetrc"} DEBOOTSTRAP_DOWNLOAD_RETRIES=3 \
            debootstrap "${opts[@]}" "$release" "$target" "$mirror" || { rm -f "$wgetrc"; return 1; }

        rootfs_set_build_stage "$target" bootstrap-second-stage
        if run_cmd "debootstrap second stage ($arch)" rootfs_run_second_stage "$target" "$arch" 1; then
            rootfs_set_build_stage "$target" bootstrap-complete
        else
            rootfs_set_build_stage "$target" bootstrap-second-stage-failed
            rm -f "$wgetrc"
            return 1
        fi
    else
        rootfs_set_build_stage "$target" bootstrap
        run_cmd "debootstrap $distro/$release" \
            env ${wgetrc:+WGETRC="$wgetrc"} DEBOOTSTRAP_DOWNLOAD_RETRIES=3 \
            debootstrap "${opts[@]}" "$release" "$target" "$mirror" || { rm -f "$wgetrc"; return 1; }
        rootfs_set_build_stage "$target" bootstrap-complete
    fi
    if [ "$distro" = ubuntu ]; then
        rootfs_prepare_ubuntu_apt "$target" "$release" "$arch" "$mirror"
    fi

    rm -f "$wgetrc"

    if [ -n "${pkgs//[[:space:]]/}" ]; then
        rootfs_set_build_stage "$target" packages
        if rootfs_install_deb_packages "$target" "$pkgs"; then
            rootfs_set_build_stage "$target" packages-complete
        else
            rootfs_set_build_stage "$target" packages-failed
            return 1
        fi
    fi
    return 0
}

build_alpine() { # release arch mirror target pkgs
    local release="$1" arch="$2" mirror="$3" target="$4" pkgs="$5"
    local mapped; mapped=$(map_packages alpine $pkgs)
    local workdir; workdir=$(mktemp -d)
    # apk.static must match the HOST arch; --arch selects the TARGET arch.
    local host_apk_arch
    case "$(uname -m)" in
        x86_64) host_apk_arch="x86_64" ;;
        aarch64) host_apk_arch="aarch64" ;;
        *) host_apk_arch="$arch" ;;
    esac
    local apkdir="$mirror/$release/main/$host_apk_arch"

    log "Fetching apk.static index from $apkdir"
    local tools_apk
    tools_apk=$(rootfs_fetch_text "$apkdir/" 2>>"$LOGFILE" | grep -o 'apk-tools-static-[^"]*\.apk' | head -n1)
    if [ -z "$tools_apk" ]; then
        warn "Could not locate apk-tools-static at $apkdir"
        rm -rf "$workdir"; return 1
    fi
    rootfs_fetch_file "$apkdir/$tools_apk" "$workdir/apk-tools.apk" || { rm -rf "$workdir"; return 1; }
    tar -xzf "$workdir/apk-tools.apk" -C "$workdir" 2>>"$LOGFILE" || { warn "Failed to extract apk-tools-static package"; rm -rf "$workdir"; return 1; }
    [ -x "$workdir/sbin/apk.static" ] || { warn "apk.static missing after extraction"; rm -rf "$workdir"; return 1; }

    run_cmd "apk.static bootstrap (alpine $release/$arch)" \
        "$workdir/sbin/apk.static" \
            -X "$mirror/$release/main" --arch "$arch" \
            --root "$target" --initdb add alpine-base $mapped
    local rc=$?
    printf '%s/%s/main\n%s/%s/community\n' "$mirror" "$release" "$mirror" "$release" \
        > "$target/etc/apk/repositories"
    rm -rf "$workdir"
    return $rc
}

build_arch() { # mirror target pkgs backend
    local mirror="$1" target="$2" pkgs="$3" backend="${4:-auto}"
    local mapped; mapped=$(map_packages arch $pkgs)
    [ "$backend" = auto ] && backend=$(rootfs_resolve_backend arch auto)
    if [ "$backend" = pacstrap ]; then
        command -v pacstrap >/dev/null 2>&1 || { tui_msg "Missing tool" "pacstrap is not installed."; return 1; }
        run_cmd "pacstrap (Arch)" pacstrap -c "$target" base $mapped
    elif [ "$backend" = arch-bootstrap ]; then
        rootfs_backend_available arch-bootstrap || { tui_msg "Missing tools" "The Arch bootstrap tarball backend requires tar, zstd, and curl or wget."; return 1; }
        local tarball="archlinux-bootstrap-x86_64.tar.zst" workdir; workdir=$(mktemp -d) || return 1
        run_cmd "Downloading Arch bootstrap tarball" \
            rootfs_fetch_file "$mirror/iso/latest/$tarball" "$workdir/$tarball" || { rm -rf "$workdir"; return 1; }
        run_cmd "Extracting bootstrap tarball" \
            tar -C "$target" --strip-components=1 --numeric-owner \
                -xf "$workdir/$tarball" || { rm -rf "$workdir"; return 1; }
        rm -rf "$workdir"
        [ -n "${mapped// }" ] && warn "Install these inside the chroot: pacman -S $mapped"
    else
        tui_msg "Unsupported backend" "'$backend' cannot build an Arch rootfs."
        return 1
    fi
}

build_fedora() { # release arch mirror target pkgs
    local release="$1" arch="$2" mirror="$3" target="$4" pkgs="$5"
    if ! command -v dnf >/dev/null; then
        tui_msg "Missing tool" \
"Fedora bootstrapping needs 'dnf' on the host.
Debian/Ubuntu: apt install dnf    Arch: pacman -S dnf
Then retry."
        return 1
    fi
    local mapped; mapped=$(map_packages fedora $pkgs)
    local repo="$mirror/releases/$release/Everything/$arch/os/"
    # --repofrompath makes this work on non-Fedora hosts (no fedora repo files).
    run_cmd "dnf --installroot (fedora $release/$arch)" \
        dnf -y --installroot="$target" --releasever="$release" \
            --repofrompath="systui-fedora,$repo" \
            --disablerepo='*' --enablerepo=systui-fedora \
            --setopt=install_weak_deps=False \
            install fedora-release dnf bash $mapped
}


build_opensuse() { # distro release debarch mirror target pkgs
    local distro="$1" release="$2" arch="$3" mirror="$4" target="$5" pkgs="$6"
    local mapped; mapped=$(map_packages opensuse "$pkgs") || return 1
    command -v zypper >/dev/null 2>&1 || {
        tui_msg "Missing tool" "openSUSE bootstrapping requires zypper on the host."; return 1; }
    local suse_arch repo
    case "$arch" in amd64) suse_arch=x86_64 ;; arm64) suse_arch=aarch64 ;; armhf) suse_arch=armv7hl ;; i386) suse_arch=i586 ;; esac
    if [ "$distro" = tumbleweed ]; then
        repo="$mirror"
    else
        repo="$mirror/$release/repo/oss/"
    fi
    run_cmd "zypper --root ($distro $release/$suse_arch)" \
        zypper --root "$target" --non-interactive ar -f "$repo" systui-oss || return 1
    run_cmd "Installing openSUSE base" \
        zypper --root "$target" --non-interactive --gpg-auto-import-keys install \
        filesystem bash coreutils rpm zypper ca-certificates iproute2 $mapped
}

build_gentoo() { # flavor debarch mirror target pkgs
    local flavor="$1" arch="$2" mirror="$3" target="$4" pkgs="$5"
    local garch stage url meta tarball workdir; workdir=$(mktemp -d) || return 1
    case "$arch" in
        amd64) garch=amd64; stage="stage3-amd64-$flavor" ;;
        arm64) garch=arm64; stage="stage3-arm64-$flavor" ;;
        armhf) garch=arm; stage="stage3-armv7a-$flavor" ;;
        i386) garch=x86; stage="stage3-i686-$flavor" ;;
        *) warn "Unsupported Gentoo architecture: $arch"; return 1 ;;
    esac
    url="$mirror/$garch/autobuilds/current-$stage"
    meta="latest-$stage.txt"
    tarball=$(rootfs_fetch_text "$url/$meta" 2>>"$LOGFILE" | awk '!/^#/ && /tar\.(xz|bz2)/ {print $1; exit}')
    [ -n "$tarball" ] || { warn "Could not discover Gentoo stage3 at $url/$meta"; return 1; }
    run_cmd "Downloading Gentoo stage3" rootfs_fetch_file "$mirror/$garch/autobuilds/$tarball" "$workdir/$(basename "$tarball")" || return 1
    run_cmd "Extracting Gentoo stage3" tar -C "$target" --numeric-owner -xpf "$workdir/$(basename "$tarball")" || { rm -rf "$workdir"; return 1; }; rm -rf "$workdir"
    printf 'GENTOO_MIRRORS="%s"\n' "$mirror" >> "$target/etc/portage/make.conf"
    [ -n "${pkgs// }" ] && warn "Gentoo extras were not installed automatically. Use Rootfs > Manage > Packages after entering the rootfs."
}

build_void() { # arch mirror target pkgs use_qemu
    local arch="$1" mirror="$2" target="$3" pkgs="$4" use_qemu="$5"
    local mapped; mapped=$(map_packages void $pkgs)
    local listing tarball workdir; workdir=$(mktemp -d) || return 1
    listing=$(rootfs_fetch_text "$mirror/live/current/" 2>>"$LOGFILE")
    tarball=$(grep -o "void-${arch}-ROOTFS-[0-9]*\.tar\.xz" <<<"$listing" | sort -u | tail -n1)
    if [ -z "$tarball" ]; then
        warn "Could not find a void-${arch}-ROOTFS tarball at $mirror/live/current/"
        return 1
    fi
    run_cmd "Downloading Void rootfs ($tarball)" \
        rootfs_fetch_file "$mirror/live/current/$tarball" "$workdir/$tarball" || return 1
    run_cmd "Extracting Void rootfs" \
        tar -C "$target" --numeric-owner -xJf "$workdir/$tarball" || { rm -rf "$workdir"; return 1; }; rm -rf "$workdir"
    if [ -n "${mapped// }" ]; then
        # Try installing extra packages via xbps inside the (possibly qemu) chroot.
        if [ "$use_qemu" = 1 ]; then
            local void_debarch=""
            case "$arch" in
                aarch64) void_debarch="arm64" ;;
                armv7l)  void_debarch="armhf" ;;
                x86_64)  void_debarch="amd64" ;;
                i686)    void_debarch="i386" ;;
            esac
            [ -n "$void_debarch" ] && setup_qemu_chroot "$target" "$void_debarch" >/dev/null 2>&1 || true
        fi
        printf 'nameserver 1.1.1.1\n' > "$target/etc/resolv.conf"
        local void_args=() vp
        mapped=$(rootfs_sanitize_packages "$mapped") || return 1
        for vp in $mapped; do void_args+=("$vp"); done
        if in_chroot "$target" xbps-install -Syu xbps && in_chroot "$target" xbps-install -y "${void_args[@]}"; then
            log "void: extra packages installed in chroot"
        else
            warn "Could not install extras in the Void chroot. Inside it, run: xbps-install -Syu && xbps-install $mapped"
        fi
    fi
}


rootfs_validate_integrity() { # <target>
    local t="$1" failed=0 pm
    [ -x "$t/bin/sh" ] || { warn "Integrity: missing executable /bin/sh"; failed=1; }
    [ -r "$t/etc/os-release" ] || { warn "Integrity: missing /etc/os-release"; failed=1; }
    pm=$(rootfs_detect_pm "$t")
    [ "$pm" != unknown ] || { warn "Integrity: package manager database not detected"; failed=1; }
    if [ -x "$t/debootstrap/debootstrap" ] && [ "$(rootfs_state_get "$t" STAGE 2>/dev/null || true)" = bootstrap-second-stage-failed ]; then
        warn "Integrity: debootstrap second stage is incomplete"; failed=1
    fi
    if [ "$pm" = apt ] && [ -x "$t/usr/bin/dpkg" ]; then
        rootfs_exec_raw "$t" dpkg --audit >>"$LOGFILE" 2>&1 || failed=1
    fi
    [ "$failed" = 0 ]
}

# ---- Rootfs management -------------------------------------------------------
enter_chroot() { # enter_chroot <target>
    local t="$1" mounts="" rc=0 shell workdir launch_cmd boot_cmd
    [ -x "$t/bin/sh" ] || { tui_msg "Error" "$t does not look like a rootfs (no /bin/sh)."; return 1; }
    shell=$(rootfs_chroot_option_get "$t" SHELL /bin/bash)
    shell=$(rootfs_shell_path "$t" "$shell")
    workdir=$(rootfs_chroot_option_get "$t" WORKDIR /root)
    launch_cmd=$(rootfs_chroot_option_get "$t" LAUNCH_CMD "")
    boot_cmd=$(rootfs_chroot_option_get "$t" BOOT_CMD "")
    [ -d "$t$workdir" ] || workdir=/
    clear
    rootfs_mount_chroot_fs "$t" || true
    mounts="${ROOTFS_ACTIVE_MOUNTS:-}"
    echo "==============================================================="
    echo " Entering chroot: $t"
    echo " Shell: $shell   Directory: $workdir"
    [ "$(rootfs_chroot_option_get "$t" MOUNT_AOK yes)" = yes ] && echo " Host /AOK: mounted at /AOK when supported"
    [ -n "$boot_cmd" ] && echo " Boot command: $boot_cmd"
    [ -n "$launch_cmd" ] && echo " Launch command: $launch_cmd"
    echo " Type 'exit' to leave."
    echo "==============================================================="
    if [ -n "$boot_cmd" ]; then
        rootfs_exec_raw "$t" "$shell" -lc "cd '$workdir' 2>/dev/null || cd /; $boot_cmd" || warn "Chroot boot command failed; continuing to launch command."
    fi
    if [ -n "$launch_cmd" ]; then
        rootfs_exec_raw "$t" "$shell" -lc "cd '$workdir' 2>/dev/null || cd /; exec $launch_cmd" || rc=$?
    else
        rootfs_exec_raw "$t" "$shell" -lc "cd '$workdir' 2>/dev/null || cd /; exec '$shell' -l" || rc=$?
    fi
    rootfs_unmount_chroot_fs "$mounts"
    echo "Left chroot; temporary mounts detached."
    read -rp "(press Enter)" _ || true
    return "$rc"
}

# ---- Rootfs chroot helpers ---------------------------------------------------
rootfs_detect_pm() { # <target> -> apt|apk|pacman|dnf|xbps|unknown
    local t="$1"
    if   [ -f "$t/etc/apk/repositories" ]; then echo apk
    elif [ -f "$t/etc/debian_version" ];   then echo apt
    elif [ -f "$t/etc/pacman.conf" ];      then echo pacman
    elif [ -f "$t/etc/fedora-release" ];   then echo dnf
    elif [ -x "$t/usr/bin/zypper" ];        then echo zypper
    elif [ -x "$t/usr/bin/emerge" ];        then echo emerge
    elif [ -x "$t/usr/bin/xbps-install" ] || [ -d "$t/etc/xbps.d" ]; then echo xbps
    else echo unknown; fi
}

rootfs_detect_init() { # <target> -> from manifest, else filesystem heuristics
    local t="$1" i=""
    [ -f "$t/etc/systui-build.conf" ] && i=$(grep -m1 '^INIT=' "$t/etc/systui-build.conf" | cut -d= -f2 | tr -d '"')
    if [ -z "$i" ]; then
        if   [ -d "$t/lib/systemd/system" ] || [ -d "$t/usr/lib/systemd/system" ]; then i=systemd
        elif [ -d "$t/etc/runit" ] || [ -d "$t/etc/sv" ]; then i=runit
        elif [ -f "$t/sbin/openrc" ] || [ -d "$t/etc/runlevels" ]; then i=openrc
        elif [ -f "$t/etc/inittab" ]; then i=sysvinit
        else i=unknown; fi
    fi
    echo "$i"
}

# Run a command inside the rootfs with /proc,/sys,/dev mounted and DNS set,
# then tear the mounts down. Output goes to the terminal via run_cmd.
rootfs_chroot_exec() { # <target> <description> <sh -c command string>
    local t="$1" desc="$2" cmd="$3" mounts="" rc=0
    rootfs_mount_chroot_fs "$t" || true
    mounts="${ROOTFS_ACTIVE_MOUNTS:-}"
    trap 'rootfs_unmount_chroot_fs "$mounts"' INT TERM HUP
    run_cmd "$desc" rootfs_exec_raw "$t" /bin/sh -c "$cmd" || rc=$?
    trap - INT TERM HUP
    rootfs_unmount_chroot_fs "$mounts"
    return "$rc"
}
rootfs_chroot_exec_args() { # <target> <description> <command> [args...]
    local t="$1" desc="$2"; shift 2
    local mounts="" rc=0
    rootfs_mount_chroot_fs "$t" || true
    mounts="${ROOTFS_ACTIVE_MOUNTS:-}"
    trap 'rootfs_unmount_chroot_fs "$mounts"' INT TERM HUP
    run_cmd "$desc" rootfs_exec_raw "$t" "$@" || rc=$?
    trap - INT TERM HUP
    rootfs_unmount_chroot_fs "$mounts"
    return "$rc"
}

# In-rootfs package management with the rootfs's own package manager.
rootfs_pkg_menu() { # <target>
    local t="$1" rpm_
    rpm_=$(rootfs_detect_pm "$t")
    [ "$rpm_" = unknown ] && { tui_msg "Unknown" "Could not detect a package manager inside\n$t"; return 0; }
    while true; do
        local c
        # Safely capture menu result and handle cancellation
        if ! c=$(tui_menu "Rootfs packages  [$rpm_]" "Package management inside $(basename "$t"):" \
            install "Install packages" \
            remove  "Remove packages" \
            upgrade "Update indexes & upgrade everything" \
            list    "List installed packages" \
            back    "Back"); then
            # User pressed ESC/Cancel - gracefully return to parent menu
            return 0
        fi
        [ -z "$c" ] && return 0
        [ "$c" = back ] && return 0
        local p=""
        case "$c" in install|remove)
            p=$(tui_input "$c" "Package names (space-separated, native $rpm_ names):" "") || continue
            [ -z "$p" ] && continue; p=$(rootfs_sanitize_packages "$p") || { tui_msg "Invalid package" "Unsafe package name rejected."; continue; } ;;
        esac
        case "$rpm_:$c" in
            apt:install)    rootfs_chroot_exec "$t" "apt install $p" "apt-get update && apt-get install -y $p" ;;
            apt:remove)     rootfs_chroot_exec "$t" "apt remove $p" "apt-get remove -y $p" ;;
            apt:upgrade)    rootfs_chroot_exec "$t" "apt upgrade" "apt-get update && apt-get upgrade -y" ;;
            apt:list)       rootfs_exec_raw "$t" dpkg-query -W -f='${Package} ${Version}\n' > "$(rootfs_report_file)" 2>&1 ;;
            apk:install)    rootfs_chroot_exec "$t" "apk add $p" "apk update && apk add $p" ;;
            apk:remove)     rootfs_chroot_exec "$t" "apk del $p" "apk del $p" ;;
            apk:upgrade)    rootfs_chroot_exec "$t" "apk upgrade" "apk update && apk upgrade" ;;
            apk:list)       rootfs_exec_raw "$t" apk info -v > "$(rootfs_report_file)" 2>&1 ;;
            pacman:install) rootfs_chroot_exec "$t" "pacman -S $p" "pacman -Sy --noconfirm --needed $p" ;;
            pacman:remove)  rootfs_chroot_exec "$t" "pacman -R $p" "pacman -Rns --noconfirm $p" ;;
            pacman:upgrade) rootfs_chroot_exec "$t" "pacman -Syu" "pacman -Syu --noconfirm" ;;
            pacman:list)    rootfs_exec_raw "$t" pacman -Q > "$(rootfs_report_file)" 2>&1 ;;
            dnf:install)    rootfs_chroot_exec "$t" "dnf install $p" "dnf install -y $p" ;;
            dnf:remove)     rootfs_chroot_exec "$t" "dnf remove $p" "dnf remove -y $p" ;;
            dnf:upgrade)    rootfs_chroot_exec "$t" "dnf upgrade" "dnf upgrade -y" ;;
            dnf:list)       rootfs_exec_raw "$t" rpm -qa > "$(rootfs_report_file)" 2>&1 ;;
            xbps:install)   rootfs_chroot_exec "$t" "xbps-install $p" "xbps-install -Sy $p" ;;
            xbps:remove)    rootfs_chroot_exec "$t" "xbps-remove $p" "xbps-remove -y $p" ;;
            xbps:upgrade)   rootfs_chroot_exec "$t" "xbps upgrade" "xbps-install -Syu" ;;
            xbps:list)      rootfs_exec_raw "$t" xbps-query -l > "$(rootfs_report_file)" 2>&1 ;;
        esac
        [ "$c" = list ] && tui_text "Installed in $(basename "$t") ($rpm_)" "$(rootfs_report_file)"
    done
}

# In-rootfs system configuration (users, hostname, DNS, services).
rootfs_cfg_menu() { # <target>
    local t="$1" rinit
    rinit=$(rootfs_detect_init "$t")
    while true; do
        local c
        # Safely capture menu result and handle cancellation
        if ! c=$(tui_menu "Rootfs config  [init: $rinit]" "Configure $(basename "$t"):" \
            hostname "Set hostname (current: $(cat "$t/etc/hostname" 2>/dev/null))" \
            rootpw   "Set root password" \
            adduser  "Add a user account" \
            dns      "Set DNS resolvers" \
            timezone "Set timezone" \
            locale   "Configure locale" \
            shell    "Set default shell" \
            editor   "Set default editor" \
            ssh      "Configure SSH server" \
            services "Enable/disable a service at boot" \
            pkgupdate "Refresh package indexes" \
            upgrade  "Upgrade installed packages" \
            cleanup  "Clean package caches" \
            mounts   "Install virtual-filesystem mount helper" \
            manifest "Edit/show build manifest" \
            osinfo   "Show OS info (os-release)" \
            back     "Back"); then
            # User pressed ESC/Cancel - gracefully return to parent menu
            return 0
        fi
        [ -z "$c" ] && return 0
        [ "$c" = back ] && return 0
        case "$c" in
            hostname)
                local h; h=$(tui_input "Hostname" "New hostname:" "$(cat "$t/etc/hostname" 2>/dev/null)") || continue
                [ -z "$h" ] && continue
                rootfs_valid_hostname "$h" || { tui_msg "Invalid hostname" "Use letters, numbers, dots, and hyphens only."; continue; }
                echo "$h" > "$t/etc/hostname"
                grep -q '127.0.1.1' "$t/etc/hosts" 2>/dev/null \
                    && sed -i "s/^127.0.1.1.*/127.0.1.1\t$h/" "$t/etc/hosts" \
                    || printf '127.0.1.1\t%s\n' "$h" >> "$t/etc/hosts"
                tui_msg "Done" "Hostname set to $h (with matching hosts entry)." ;;
            rootpw)
                local p; p=$(tui_password "Root password" "New root password for this rootfs:") || continue
                [ -z "$p" ] && continue
                echo "root:$p" | rootfs_exec_raw "$t" chpasswd 2>>"$LOGFILE" \
                    && tui_msg "Done" "Root password updated." \
                    || tui_msg "Failed" "chpasswd failed in chroot (foreign arch without qemu?)." ;;
            adduser)
                local u p
                u=$(tui_input "New user" "Username:" "") || continue; [ -z "$u" ] && continue; rootfs_valid_username "$u" || { tui_msg "Invalid username" "Use lowercase letters, numbers, underscores, and hyphens."; continue; }
                if rootfs_exec_raw "$t" sh -c "command -v useradd" >/dev/null 2>&1; then
                    rootfs_exec_raw "$t" useradd -m -s /bin/sh "$u" 2>>"$LOGFILE"
                else
                    rootfs_exec_raw "$t" adduser -D "$u" 2>>"$LOGFILE"
                fi
                p=$(tui_password "Password" "Password for $u (blank = locked):")
                [ -n "$p" ] && echo "$u:$p" | rootfs_exec_raw "$t" chpasswd 2>>"$LOGFILE"
                tui_msg "Done" "User $u created in the rootfs." ;;
            dns)
                local d
                d=$(tui_radio "DNS" "Resolvers for the rootfs (SPACE to select):" \
                    cloudflare "1.1.1.1 / 1.0.0.1" on \
                    google     "8.8.8.8 / 8.8.4.4" off \
                    quad9      "9.9.9.9 / 149.112.112.112" off) || continue
                case "$d" in
                    cloudflare) printf 'nameserver 1.1.1.1\nnameserver 1.0.0.1\n' > "$t/etc/resolv.conf" ;;
                    google)     printf 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n' > "$t/etc/resolv.conf" ;;
                    quad9)      printf 'nameserver 9.9.9.9\nnameserver 149.112.112.112\n' > "$t/etc/resolv.conf" ;;
                    *) continue ;;
                esac
                tui_msg "Done" "resolv.conf written in the rootfs." ;;
            timezone)
                local z; z=$(tui_input "Timezone" "IANA timezone:" "UTC") || continue
                [ -e "$t/usr/share/zoneinfo/$z" ] && { ln -sf "/usr/share/zoneinfo/$z" "$t/etc/localtime"; echo "$z" > "$t/etc/timezone"; tui_msg "Done" "Timezone set to $z."; } || tui_msg "Missing" "Timezone data is not installed." ;;
            locale)
                local l; l=$(tui_input "Locale" "Locale:" "C.UTF-8") || continue
                mkdir -p "$t/etc/profile.d"; printf 'export LANG=%s\nexport LC_ALL=%s\n' "$l" "$l" > "$t/etc/profile.d/locale.sh"
                [ -f "$t/etc/locale.gen" ] && { grep -qF "$l UTF-8" "$t/etc/locale.gen" || echo "$l UTF-8" >> "$t/etc/locale.gen"; rootfs_chroot_exec "$t" "Generate locale" "locale-gen || true"; }
                tui_msg "Done" "Locale configured as $l." ;;
            shell)
                local shv u; shv=$(tui_radio "Default shell" "Shell:" bash Bash on zsh Zsh off fish Fish off) || continue
                u=$(tui_input "Account" "Account to update:" "root") || continue
                rootfs_chroot_exec "$t" "Set shell for $u" "chsh -s $( [ "$shv" = fish ] && echo /usr/bin/fish || echo /bin/$shv ) $u" ;;
            editor)
                local ed; ed=$(tui_radio "Default editor" "Editor:" nano Nano on vim Vim off neovim Neovim off micro Micro off) || continue
                mkdir -p "$t/etc/profile.d"; printf 'export EDITOR=%s\nexport VISUAL=%s\n' "$ed" "$ed" > "$t/etc/profile.d/editor.sh"
                tui_msg "Done" "Default editor set to $ed." ;;
            ssh)
                local port rootlogin passauth
                port=$(tui_input "SSH" "Port:" "22") || continue
                rootlogin=$(tui_radio "SSH root login" "Policy:" no "Prohibit root password login" on yes "Allow root login" off) || continue
                passauth=$(tui_radio "SSH passwords" "Password authentication:" yes Enabled on no Disabled off) || continue
                [ -f "$t/etc/ssh/sshd_config" ] || { tui_msg "Missing" "OpenSSH server is not installed."; continue; }
                sed -i -E "s/^#?Port .*/Port $port/; s/^#?PermitRootLogin .*/PermitRootLogin $([ "$rootlogin" = yes ] && echo yes || echo prohibit-password)/; s/^#?PasswordAuthentication .*/PasswordAuthentication $passauth/" "$t/etc/ssh/sshd_config"
                rootfs_chroot_exec "$t" "Validate sshd configuration" "sshd -t" || true ;;
            pkgupdate)
                case "$(rootfs_detect_pm "$t")" in apt) rootfs_chroot_exec "$t" "apt update" "apt-get update" ;; apk) rootfs_chroot_exec "$t" "apk update" "apk update" ;; pacman) rootfs_chroot_exec "$t" "pacman sync" "pacman -Sy --noconfirm" ;; dnf) rootfs_chroot_exec "$t" "dnf cache" "dnf makecache" ;; xbps) rootfs_chroot_exec "$t" "xbps sync" "xbps-install -S" ;; esac ;;
            upgrade)
                case "$(rootfs_detect_pm "$t")" in apt) rootfs_chroot_exec "$t" "apt upgrade" "apt-get upgrade -y" ;; apk) rootfs_chroot_exec "$t" "apk upgrade" "apk upgrade" ;; pacman) rootfs_chroot_exec "$t" "pacman upgrade" "pacman -Syu --noconfirm" ;; dnf) rootfs_chroot_exec "$t" "dnf upgrade" "dnf upgrade -y" ;; xbps) rootfs_chroot_exec "$t" "xbps upgrade" "xbps-install -yu" ;; esac ;;
            cleanup)
                case "$(rootfs_detect_pm "$t")" in apt) rootfs_chroot_exec "$t" "apt clean" "apt-get autoremove -y; apt-get clean" ;; apk) rm -rf "$t/var/cache/apk"/* ;; pacman) rm -rf "$t/var/cache/pacman/pkg"/* ;; dnf) rootfs_chroot_exec "$t" "dnf clean" "dnf clean all" ;; xbps) rm -rf "$t/var/cache/xbps"/* ;; esac
                tui_msg "Done" "Package caches cleaned." ;;
            mounts)
                mkdir -p "$t/usr/local/sbin"; cat > "$t/usr/local/sbin/mount-rootfs-virtualfs" <<'EOF'
#!/bin/sh
mountpoint -q /proc || mount -t proc proc /proc
mountpoint -q /sys || mount -t sysfs sysfs /sys
mkdir -p /run /dev/pts
mountpoint -q /dev/pts || mount -t devpts devpts /dev/pts
EOF
                chmod +x "$t/usr/local/sbin/mount-rootfs-virtualfs"; tui_msg "Done" "Mount helper installed." ;;
            manifest)
                if [ -f "$t/etc/systui-build.conf" ]; then ${EDITOR:-nano} "$t/etc/systui-build.conf" </dev/tty >/dev/tty 2>/dev/tty || tui_text "Manifest" "$t/etc/systui-build.conf"; else tui_msg "Missing" "No build manifest exists."; fi ;;
            services)
                local s a
                a=$(tui_radio "Service" "Action (SPACE to select):" \
                    enable  "Enable at boot" on \
                    disable "Disable at boot" off) || continue
                s=$(tui_input "Service" "Service name (as the rootfs's init knows it):" "") || continue
                [ -z "$s" ] && continue
                case "$rinit" in
                    systemd)
                        rootfs_chroot_exec "$t" "systemctl $a $s" "systemctl $a $s" ;;
                    openrc)
                        if [ "$a" = enable ]; then
                            rootfs_chroot_exec "$t" "rc-update add $s" "rc-update add $s default"
                        else
                            rootfs_chroot_exec "$t" "rc-update del $s" "rc-update del $s default"
                        fi ;;
                    runit)
                        mkdir -p "$t/etc/runit/runsvdir/default"
                        if [ "$a" = enable ]; then
                            [ -d "$t/etc/sv/$s" ] && ln -sf "/etc/sv/$s" "$t/etc/runit/runsvdir/default/" \
                                && tui_msg "Done" "$s linked into the default runlevel." \
                                || tui_msg "Missing" "No /etc/sv/$s in the rootfs."
                        else
                            rm -f "$t/etc/runit/runsvdir/default/$s"
                            tui_msg "Done" "$s unlinked from the default runlevel."
                        fi ;;
                    sysvinit)
                        if [ "$a" = enable ]; then
                            rootfs_chroot_exec "$t" "update-rc.d $s defaults" "update-rc.d $s defaults"
                        else
                            rootfs_chroot_exec "$t" "update-rc.d $s remove" "update-rc.d $s remove"
                        fi ;;
                    *) tui_msg "Unknown" "Init system of the rootfs is unknown —\nmanage services manually inside the chroot." ;;
                esac ;;
            osinfo)
                { cat "$t/etc/os-release" 2>/dev/null || echo "(no os-release)"
                  echo
                  echo "Detected PM  : $(rootfs_detect_pm "$t")"
                  echo "Detected init: $rinit"
                } > "$(rootfs_report_file)"
                tui_text "OS info: $(basename "$t")" "$(rootfs_report_file)" ;;
            back) return 0 ;;
        esac
    done
}

rootfs_manage() {
    local base
    # Safely capture input result and handle cancellation
    if ! base=$(tui_input "Manage rootfs" "Base directory containing rootfs builds:" "$ROOTFS_BASE"); then
        # User pressed ESC/Cancel - gracefully return
        return 0
    fi
    [ -z "$base" ] && return 0
    [ -d "$base" ] || { tui_msg "Not found" "$base does not exist."; return 0; }

    while true; do
        # Build the selection menu from directories present.
        local d tags=() n=0
        for d in "$base"/*/; do
            [ -d "$d" ] || continue
            d=${d%/}
            tags+=("$d" "$(du -sh "$d" 2>/dev/null | cut -f1) $( [ -f "$d/etc/systui-build.conf" ] && echo '[systui]')")
            n=$((n+1))
        done
        [ $n = 0 ] && { tui_msg "Empty" "No rootfs directories found in $base."; return 0; }
        local sel
        # Safely capture menu result and handle cancellation
        if ! sel=$(tui_menu "Rootfs in $base" "Select a rootfs:" "${tags[@]}" __back "Back"); then
            # User pressed ESC/Cancel - gracefully return
            return 0
        fi
        [ -z "$sel" ] && return 0
        [ "$sel" = __back ] && return 0

        local c
        # Safely capture submenu result and handle cancellation
        if ! c=$(tui_menu "$(basename "$sel")" \
            "PM: $(rootfs_detect_pm "$sel")  init: $(rootfs_detect_init "$sel")" \
            continue "Continue/recover rootfs generation" \
            backendcfg "Configure the recorded bootstrap backend" \
            enter    "Enter chroot (interactive shell)" \
            entrycfg "Configure chroot entry options" \
            cmd      "Run a single command in the chroot" \
            pkg      "Package management (inside the rootfs)" \
            config   "In-rootfs configuration (identity, locale, SSH, services...)" \
            manifest "Show build manifest" \
            size     "Show size breakdown" \
            compress "Compress to an archive" \
            clone    "Clone to a new directory" \
            rename   "Rename this rootfs" \
            delete   "DELETE this rootfs" \
            back     "Back"); then
            # User pressed ESC/Cancel - return to rootfs selection
            continue
        fi
        [ -z "$c" ] && continue
        case "$c" in
            continue) rootfs_continue_generation "$sel" ;;
            backendcfg) rootfs_backend_reconfigure "$sel" ;;
            enter) enter_chroot "$sel" ;;
            entrycfg) rootfs_chroot_options_menu "$sel" ;;
            cmd)
                local rcmd
                rcmd=$(tui_input "Chroot command" "Command to run inside $(basename "$sel"):" "") || continue
                [ -n "$rcmd" ] && rootfs_chroot_exec "$sel" "chroot: $rcmd" "$rcmd" ;;
            pkg)    rootfs_pkg_menu "$sel" ;;
            config) rootfs_cfg_menu "$sel" ;;
            clone)
                local dst
                dst=$(tui_input "Clone" "New directory for the copy:" "${sel}-copy") || continue
                [ -z "$dst" ] && continue
                [ -e "$dst" ] && { tui_msg "Exists" "$dst already exists."; continue; }
                run_cmd "Cloning rootfs -> $dst" cp -a "$sel" "$dst" ;;
            rename)
                local dst
                dst=$(tui_input "Rename" "New name (directory under $base):" "$(basename "$sel")") || continue
                [ -z "$dst" ] || [ "$dst" = "$(basename "$sel")" ] && continue
                [ -e "$base/$dst" ] && { tui_msg "Exists" "$base/$dst already exists."; continue; }
                mv "$sel" "$base/$dst" && tui_msg "Done" "Renamed to $base/$dst" ;;
            manifest)
                if [ -f "$sel/etc/systui-build.conf" ]; then
                    tui_text "Manifest" "$sel/etc/systui-build.conf"
                else
                    tui_msg "No manifest" "No /etc/systui-build.conf in this rootfs\n(built by hand or with the manifest option off)."
                fi ;;
            size)
                du -xh --max-depth=1 "$sel" 2>/dev/null | sort -hr | head -25 > "$(rootfs_report_file)"
                tui_text "Size: $(basename "$sel")" "$(rootfs_report_file)" ;;
            compress)
                local comp
                comp=$(tui_radio "Compress" "Format (SPACE to select):" \
                    gz  "tar.gz (default, compatible)" on \
                    zst "tar.zst (fast)" off \
                    xz  "tar.xz" off) || continue
                [ -z "$comp" ] && continue
                local ext
                case "$comp" in
                    zst) ext="tar.zst"; command -v zstd >/dev/null || { tui_msg "Missing tool" "zstd is required for tar.zst archives."; continue; }; run_cmd "Compressing -> $sel.$ext" tar --zstd -C "$sel" --numeric-owner -cf "$sel.$ext" . ;;
                    gz)  ext="tar.gz"; run_cmd "Compressing -> $sel.$ext" tar -C "$sel" --numeric-owner -czf "$sel.$ext" . ;;
                    xz)  ext="tar.xz"; run_cmd "Compressing -> $sel.$ext" tar -C "$sel" --numeric-owner -cJf "$sel.$ext" . ;;
                esac ;;
            delete)
                local typed
                tui_yesno "DELETE" "Recursively delete:\n$sel\n\nThis cannot be undone. Continue?" || continue
                typed=$(tui_input "Type to confirm" "Type the directory name ($(basename "$sel")) to confirm:" "") || continue
                [ "$typed" != "$(basename "$sel")" ] && { tui_msg "Aborted" "Confirmation did not match."; continue; }
                run_cmd "Deleting $sel" rm -rf --one-file-system "$sel" ;;
            back) : ;;
        esac
    done
}


###############################################################################
# PART 2 — SYSTEM CONFIGURATION (current system)
###############################################################################

# ---- Environment detection -------------------------------------------------
