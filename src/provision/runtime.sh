#!/bin/bash
# Shared runtime analysis and distribution adapters for provision scripts.

provision_analyze_system() {
    PROV_OS_ID=unknown PROV_OS_LIKE='' PROV_OS_NAME=unknown PROV_OS_VERSION=unknown
    local f k v
    for f in /etc/os-release /usr/lib/os-release; do
        [ -r "$f" ] || continue
        while IFS='=' read -r k v; do
            v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
            case "$k" in
                ID) PROV_OS_ID=$v ;;
                ID_LIKE) PROV_OS_LIKE=$v ;;
                PRETTY_NAME) PROV_OS_NAME=$v ;;
                VERSION_ID) PROV_OS_VERSION=$v ;;
            esac
        done < "$f"
        break
    done
    PROV_ARCH=$(uname -m 2>/dev/null || echo unknown)
    PROV_KERNEL=$(uname -s 2>/dev/null || echo unknown)
    PROV_CONTAINER=0
    [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qaE '(docker|containerd|lxc|podman|kubepods)' /proc/1/cgroup 2>/dev/null && PROV_CONTAINER=1
    PROV_CHROOT=0
    [ -r /proc/1/root ] && [ "$(stat -c %d:%i / 2>/dev/null)" != "$(stat -Lc %d:%i /proc/1/root 2>/dev/null)" ] && PROV_CHROOT=1
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then PROV_INIT=systemd
    elif command -v rc-service >/dev/null 2>&1; then PROV_INIT=openrc
    elif command -v sv >/dev/null 2>&1; then PROV_INIT=runit
    elif command -v s6-rc >/dev/null 2>&1; then PROV_INIT=s6
    elif command -v update-rc.d >/dev/null 2>&1 || command -v service >/dev/null 2>&1; then PROV_INIT=sysvinit
    else PROV_INIT=none; fi
    if command -v apk >/dev/null 2>&1; then PROV_PM=apk
    elif command -v apt-get >/dev/null 2>&1; then PROV_PM=apt
    elif command -v pacman >/dev/null 2>&1; then PROV_PM=pacman
    elif command -v dnf >/dev/null 2>&1; then PROV_PM=dnf
    elif command -v xbps-install >/dev/null 2>&1; then PROV_PM=xbps
    elif command -v zypper >/dev/null 2>&1; then PROV_PM=zypper
    elif command -v emerge >/dev/null 2>&1; then PROV_PM=portage
    else PROV_PM=unknown; fi
    export PROV_OS_ID PROV_OS_LIKE PROV_OS_NAME PROV_OS_VERSION PROV_ARCH PROV_KERNEL PROV_CONTAINER PROV_CHROOT PROV_INIT PROV_PM
}

provision_family_matches() {
    local expected="$1" all=" $PROV_OS_ID $PROV_OS_LIKE "
    case "$expected" in
        alpine) [[ "$all" == *" alpine "* ]] ;;
        archlinux) [[ "$all" == *" arch "* || "$all" == *" archlinux "* ]] ;;
        debian) [[ "$all" == *" debian "* || "$all" == *" ubuntu "* ]] && [[ "$PROV_OS_ID" != devuan ]] ;;
        devuan) [ "$PROV_OS_ID" = devuan ] || [[ "$all" == *" devuan "* ]] ;;
        *) return 1 ;;
    esac
}

provision_require_family() {
    local expected="$1"
    provision_analyze_system
    log "System analysis: ${PROV_OS_NAME} (${PROV_OS_ID} ${PROV_OS_VERSION}), arch=${PROV_ARCH}, init=${PROV_INIT}, package-manager=${PROV_PM}, container=${PROV_CONTAINER}, chroot=${PROV_CHROOT}"
    provision_family_matches "$expected" || {
        log "ERROR: This template targets $expected but detected ${PROV_OS_ID} (${PROV_OS_LIKE:-no ID_LIKE})."
        return 2
    }
}

provision_service_enable_start() {
    local service_name="$1" boot_name="${2:-$1}"
    [ "$PROV_CHROOT" = 1 ] && return 0
    case "$PROV_INIT" in
        systemd) systemctl enable "$service_name" >/dev/null 2>&1 || true; systemctl restart "$service_name" >/dev/null 2>&1 || systemctl start "$service_name" >/dev/null 2>&1 || true ;;
        openrc) rc-update add "$boot_name" default >/dev/null 2>&1 || true; rc-service "$boot_name" restart >/dev/null 2>&1 || rc-service "$boot_name" start >/dev/null 2>&1 || true ;;
        runit) [ -d "/etc/sv/$boot_name" ] && { mkdir -p /var/service; ln -sfn "/etc/sv/$boot_name" "/var/service/$boot_name"; }; sv restart "$boot_name" >/dev/null 2>&1 || sv up "$boot_name" >/dev/null 2>&1 || true ;;
        sysvinit) update-rc.d "$boot_name" defaults >/dev/null 2>&1 || update-rc.d "$boot_name" enable >/dev/null 2>&1 || true; service "$boot_name" restart >/dev/null 2>&1 || service "$boot_name" start >/dev/null 2>&1 || true ;;
    esac
}

provision_add_packages_available() {
    local p
    case "$PROV_PM" in
        apt)
            apt-get update || return 1
            for p in "$@"; do apt-cache show "$p" >/dev/null 2>&1 && apt-get install -y --no-install-recommends "$p" || log "Skipping unavailable package: $p"; done ;;
        apk) for p in "$@"; do apk search -e "$p" >/dev/null 2>&1 && apk add --no-progress "$p" || log "Skipping unavailable package: $p"; done ;;
        pacman) for p in "$@"; do pacman -Si "$p" >/dev/null 2>&1 && pacman -S --needed --noconfirm "$p" || log "Skipping unavailable package: $p"; done ;;
    esac
}
