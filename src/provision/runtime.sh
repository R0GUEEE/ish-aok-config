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

###############################################################################
# SSHD CONFIGURATION
###############################################################################

# provision_configure_sshd <port> <permit_root_login:0|1> [x11:yes|no]
#
# Replaces the previous approach of `sed -i` against /etc/ssh/sshd_config,
# which silently did nothing on a stock config. The anchors were inconsistent:
# `^#Port` and `^#PasswordAuthentication` only matched while those lines were
# still commented, whereas `^PermitRootLogin` only matched once it had been
# uncommented -- and Debian, Devuan, Arch and Alpine all ship it commented, so
# the root-login policy the user selected was discarded without a word.
#
# A drop-in under sshd_config.d is unambiguous, idempotent across re-runs, and
# reversible. The result is validated with `sshd -t` and rolled back if it does
# not parse, matching what src/features/sysconfig.sh already does.
provision_configure_sshd() {
    local port="$1" root_login="$2" x11="${3:-no}"
    local cfg=/etc/ssh/sshd_config
    local dropin_dir=/etc/ssh/sshd_config.d
    local dropin="$dropin_dir/20-systui.conf"
    local root_policy backup

    case "$port" in
        ''|*[!0-9]*) log "ERROR: refusing to configure sshd with a non-numeric port: $port"; return 1 ;;
    esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log "ERROR: refusing to configure sshd with out-of-range port: $port"
        return 1
    fi

    [ -f "$cfg" ] || { log "ERROR: $cfg does not exist; is an SSH server installed?"; return 1; }

    if [ "$root_login" = 1 ]; then root_policy=yes; else root_policy=no; fi

    mkdir -p "$dropin_dir" || return 1
    chmod 0755 "$dropin_dir" 2>/dev/null || true

    # sshd takes the FIRST value it sees for most keywords, so the Include has
    # to precede the shipped defaults rather than be appended.
    if ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$cfg"; then
        backup="$cfg.systui.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "$cfg" "$backup" || return 1
        printf 'Include /etc/ssh/sshd_config.d/*.conf\n\n' | cat - "$cfg" > "$cfg.systui.new" &&
            cat "$cfg.systui.new" > "$cfg" && rm -f "$cfg.systui.new"
        # Very old sshd builds have no Include support. Detect that and revert.
        if command -v sshd >/dev/null 2>&1 && ! sshd -t 2>/dev/null; then
            log "sshd does not support Include; falling back to in-place edits."
            cat "$backup" > "$cfg"
            rm -f "$cfg.systui.new"
            provision_configure_sshd_inplace "$port" "$root_policy" "$x11"
            return $?
        fi
    fi

    cat > "$dropin" <<EOF
# Managed by systui. Edits here are replaced on the next provisioning run.
Port $port
PermitRootLogin $root_policy
PasswordAuthentication yes
PubkeyAuthentication yes
X11Forwarding $x11
StrictModes yes
ClientAliveInterval 300
EOF
    chmod 0644 "$dropin" || true

    if command -v sshd >/dev/null 2>&1 && ! sshd -t 2>>"${LOGFILE:-/dev/null}"; then
        log "ERROR: sshd rejected the generated configuration; rolling back $dropin"
        rm -f "$dropin"
        return 1
    fi
    log "sshd configured: port=$port PermitRootLogin=$root_policy X11Forwarding=$x11"
}

# Fallback for sshd builds without Include support. Handles both the commented
# and uncommented form of each keyword, and appends the setting if neither is
# present -- so it works on a stock config and is idempotent on re-runs.
provision_configure_sshd_inplace() {
    local port="$1" root_policy="$2" x11="$3"
    local cfg=/etc/ssh/sshd_config key value
    set -- "Port:$port" "PermitRootLogin:$root_policy" "PasswordAuthentication:yes" \
           "X11Forwarding:$x11" "StrictModes:yes" "ClientAliveInterval:300"
    for pair in "$@"; do
        key=${pair%%:*}; value=${pair#*:}
        if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$cfg"; then
            sed -i "0,/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]].*/s//${key} ${value}/" "$cfg"
        else
            printf '%s %s\n' "$key" "$value" >> "$cfg"
        fi
    done
    if command -v sshd >/dev/null 2>&1 && ! sshd -t 2>>"${LOGFILE:-/dev/null}"; then
        log "ERROR: sshd rejected the in-place configuration."
        return 1
    fi
}

###############################################################################
# CONFIGURATION FILE LOADING
###############################################################################

# provision_load_config <file>
#
# The config file is a shell script and is *executed*, not parsed -- so it runs
# with full root privileges and shares a namespace with the tool. Previously it
# could therefore redefine systui's own internals (LOGFILE, SYSTUI_TMP, PM,
# DISTRO, PATH, ...) and silently redirect logging or package operations.
#
# Sourcing still happens, because existing config files rely on shell syntax,
# but the values systui depends on are snapshotted and restored afterwards, and
# any attempt to change them is reported rather than applied.
provision_load_config() {
    local file="$1"
    [ -n "$file" ] && [ -f "$file" ] || return 0

    local guarded="LOGFILE WARNFILE SYSTUI_TMP SYSTUI_TMP_ROOT PM INIT DISTRO
                   DISTRO_ID_LIKE DISTRO_VERSION DISTRO_PRETTY_NAME PATH IFS
                   PROV_PM PROV_INIT PROV_OS_ID"
    local name saved_names=() saved_values=() v
    for name in $guarded; do
        eval "v=\${$name-}"
        saved_names+=("$name")
        saved_values+=("$v")
    done

    # shellcheck source=/dev/null
    source "$file" || log "WARN: Failed to source config file $file"

    local i changed=""
    for i in "${!saved_names[@]}"; do
        name="${saved_names[$i]}"
        eval "v=\${$name-}"
        if [ "$v" != "${saved_values[$i]}" ]; then
            changed="$changed $name"
            eval "$name=\"\${saved_values[\$i]}\""
        fi
    done
    [ -n "$changed" ] && log "WARN: config file $file tried to change systui internals; reverted:$changed"
    return 0
}
