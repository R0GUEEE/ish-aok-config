#!/bin/bash
###############################################################################
# systui — Core Configuration & System Detection
###############################################################################

set -eE

# Project info
SYSTUI_VERSION="1.0.0"
SYSTUI_TITLE="systui — Linux System TUI"
BACKTITLE="iSH-AOK · systui v${SYSTUI_VERSION}"

# Logging
LOGFILE="/tmp/systui.log"
WARNFILE="/tmp/systui.warnings"
: > "$LOGFILE"
: > "$WARNFILE"

# Dialog
export DIALOG="${DIALOG:-dialog}"

# Colors (for manual terminal output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    else
        DISTRO="unknown"
        DISTRO_VERSION="unknown"
    fi
    export DISTRO DISTRO_VERSION
    log "Detected distro: $DISTRO $DISTRO_VERSION"
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
