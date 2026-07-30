#!/bin/bash
###############################################################################
# systui — Core Configuration & System Detection
###############################################################################

set -eE

# Project info
SYSTUI_VERSION="1.0.0"
SYSTUI_TITLE="systui — Linux System TUI"
BACKTITLE="iSH-AOK · systui v${SYSTUI_VERSION}"
export SYSTUI_TITLE BACKTITLE

# Logging. Never trust a caller-provided SYSTUI_TMP as an owned directory: the
# application runs as root and removes its workspace on exit. Callers may
# choose the parent directory through SYSTUI_TMP_ROOT or TMPDIR instead.
SYSTUI_TMP_ROOT="${SYSTUI_TMP_ROOT:-${TMPDIR:-/tmp}}"
[ -d "$SYSTUI_TMP_ROOT" ] || { echo "Temporary directory does not exist: $SYSTUI_TMP_ROOT" >&2; exit 1; }
SYSTUI_TMP_ROOT=$(cd -- "$SYSTUI_TMP_ROOT" && pwd -P)
SYSTUI_TMP=$(mktemp -d "$SYSTUI_TMP_ROOT/systui.XXXXXX") || exit 1
chmod 700 "$SYSTUI_TMP"
: > "$SYSTUI_TMP/.systui-owned"
export SYSTUI_TMP
LOGFILE="$SYSTUI_TMP/systui.log"
WARNFILE="$SYSTUI_TMP/systui.warnings"
: > "$LOGFILE"
: > "$WARNFILE"
cleanup_systui_tmp() {
    case "${SYSTUI_TMP:-}" in
        "$SYSTUI_TMP_ROOT"/systui.*)
            [ -f "$SYSTUI_TMP/.systui-owned" ] && rm -rf -- "$SYSTUI_TMP"
            ;;
    esac
}
trap cleanup_systui_tmp EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Dialog
export DIALOG="${DIALOG:-dialog}"

# Colors (for manual terminal output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
export RED GREEN YELLOW BLUE CYAN NC

###############################################################################
# LOGGING & ERROR HANDLING
###############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

warn() {
    echo "$*" >> "$WARNFILE"
    log "WARN: $*"
}

die() {
    log "FATAL: $*"
    echo -e "${RED}Fatal: $*${NC}" >&2
    exit 1
}

trap 'die "Unexpected error on line $LINENO"' ERR

###############################################################################
# SYSTEM DETECTION
###############################################################################

detect_pm() {
    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        PM="apt"
    elif command -v apk >/dev/null 2>&1; then
        PM="apk"
    elif command -v pacman >/dev/null 2>&1; then
        PM="pacman"
    elif command -v dnf >/dev/null 2>&1; then
        PM="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        PM="zypper"
    elif command -v yum >/dev/null 2>&1; then
        PM="yum"
    elif command -v xbps-install >/dev/null 2>&1; then
        PM="xbps"
    elif command -v emerge >/dev/null 2>&1; then
        PM="emerge"
    else
        PM=""
    fi
    export PM
    log "Detected package manager: $PM"
}

detect_init() {
    # Detect init system
    if [ -d /run/systemd/system ]; then
        INIT="systemd"
    elif command -v rc-service >/dev/null 2>&1; then
        INIT="openrc"
    elif command -v service >/dev/null 2>&1 && [ -d /etc/init.d ]; then
        INIT="sysvinit"
    elif command -v runit >/dev/null 2>&1; then
        INIT="runit"
    else
        INIT=""
    fi
    export INIT
    log "Detected init system: $INIT"
}

detect_distro() {
    # Detect Linux distribution without leaking variables from os-release.
    local os_release="" id="" id_like="" version_id="" pretty_name=""

    if [ -r /etc/os-release ]; then
        os_release=/etc/os-release
    elif [ -r /usr/lib/os-release ]; then
        os_release=/usr/lib/os-release
    fi

    if [ -n "$os_release" ]; then
        id=$(sed -n 's/^ID=//p' "$os_release" | head -n1 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        id_like=$(sed -n 's/^ID_LIKE=//p' "$os_release" | head -n1 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        version_id=$(sed -n 's/^VERSION_ID=//p' "$os_release" | head -n1 | tr -d '"')
        pretty_name=$(sed -n 's/^PRETTY_NAME=//p' "$os_release" | head -n1 | sed 's/^"//;s/"$//')
    fi

    # Fallbacks for stripped-down root filesystems lacking os-release.
    if [ -z "$id" ]; then
        if [ -r /etc/devuan_version ]; then id=devuan
        elif [ -r /etc/debian_version ]; then id=debian
        elif [ -r /etc/alpine-release ]; then id=alpine
        elif [ -r /etc/arch-release ]; then id=archlinux
        elif [ -r /etc/fedora-release ]; then id=fedora
        elif [ -r /etc/gentoo-release ]; then id=gentoo
        elif command -v xbps-install >/dev/null 2>&1; then id=void
        else id=unknown
        fi
    fi

    DISTRO="$id"
    DISTRO_ID_LIKE="$id_like"
    DISTRO_VERSION="${version_id:-unknown}"
    DISTRO_PRETTY_NAME="${pretty_name:-$id}"
    export DISTRO DISTRO_ID_LIKE DISTRO_VERSION DISTRO_PRETTY_NAME
    log "Detected distro: $DISTRO_PRETTY_NAME (id=$DISTRO, like=${DISTRO_ID_LIKE:-none}, version=$DISTRO_VERSION)"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "systui must run as root (rootfs builds and system config need it).\nTry: sudo $0"
    fi
}

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

show_warnings() {
    if [ -s "$WARNFILE" ]; then
        local text=""
        while IFS= read -r w; do text+="* $w\n"; done < "$WARNFILE"
        # Simple text display (for non-TUI environments)
        echo -e "${YELLOW}Warnings:${NC}\n$text" >&2
        : > "$WARNFILE"
    fi
}

# Simple configuration reader
get_config() {
    local key="$1" default="${2:-}"
    if [ -f ~/.systui/config ]; then
        grep "^$key=" ~/.systui/config | cut -d= -f2- || echo "$default"
    else
        echo "$default"
    fi
}

set_config() {
    local key="$1" value="$2"
    mkdir -p ~/.systui
    if grep -q "^$key=" ~/.systui/config 2>/dev/null; then
        sed -i "s|^$key=.*|$key=$value|" ~/.systui/config
    else
        echo "$key=$value" >> ~/.systui/config
    fi
}

export -f log warn die get_config set_config
