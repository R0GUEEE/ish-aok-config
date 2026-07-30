#!/bin/bash
# Menu for configuring and running the bundled provision-system script.

script_provision_defaults() {
    : "${SCRIPT_PROV_TZ:=America/Los_Angeles}"
    : "${SCRIPT_PROV_USER:=${SUDO_USER:-}}"
    if [ -z "$SCRIPT_PROV_USER" ] || [ "$SCRIPT_PROV_USER" = root ]; then
        SCRIPT_PROV_USER=$(awk -F: '$3>=1000 && $3<2000 {print $1; exit}' /etc/passwd 2>/dev/null || true)
    fi
    : "${SCRIPT_PROV_USER:=aok}"
    : "${SCRIPT_PROV_HOST:=$(cat /etc/hostname 2>/dev/null || true)}"
    [ -n "$SCRIPT_PROV_HOST" ] && [ "$SCRIPT_PROV_HOST" != localhost ] || SCRIPT_PROV_HOST=linux-ultimate
    : "${SCRIPT_PROV_NOPASS:=0}"
}

script_provision_config_file() {
    printf '%s\n' "${SYSTUI_PROVISION_CONFIG:-/etc/systui/provision-system.conf}"
}

script_provision_load() {
    local config_file key value
    config_file=$(script_provision_config_file)
    if [ -r "$config_file" ]; then
        while IFS='=' read -r key value; do
            case "$key" in
                SCRIPT_PROV_TZ) SCRIPT_PROV_TZ="$value" ;;
                SCRIPT_PROV_USER) SCRIPT_PROV_USER="$value" ;;
                SCRIPT_PROV_HOST) SCRIPT_PROV_HOST="$value" ;;
                SCRIPT_PROV_NOPASS) SCRIPT_PROV_NOPASS="$value" ;;
            esac
        done < "$config_file"
    fi
    script_provision_defaults
}

script_provision_save() {
    local config_file config_dir
    config_file=$(script_provision_config_file)
    config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"
    {
        printf 'SCRIPT_PROV_TZ=%s\n' "$SCRIPT_PROV_TZ"
        printf 'SCRIPT_PROV_USER=%s\n' "$SCRIPT_PROV_USER"
        printf 'SCRIPT_PROV_HOST=%s\n' "$SCRIPT_PROV_HOST"
        printf 'SCRIPT_PROV_NOPASS=%s\n' "$SCRIPT_PROV_NOPASS"
    } > "$config_file"
    chmod 0600 "$config_file"
}

script_provision_review() {
    local review_file="$SYSTUI_TMP/provision-system.review"
    {
        echo "PROVISION SYSTEM"
        echo
        echo "Script: $LIBDIR/src/provision/provision-system.sh"
        echo "Detected system: ${DISTRO_PRETTY_NAME:-${DISTRO:-unknown}}"
        echo "Package manager: ${PM:-unknown}"
        echo "Init system: ${INIT:-unknown}"
        echo
        echo "Timezone: $SCRIPT_PROV_TZ"
        echo "Primary login: $SCRIPT_PROV_USER"
        echo "Hostname: $SCRIPT_PROV_HOST"
        if [ "$SCRIPT_PROV_NOPASS" = 1 ]; then
            echo "Sudo: passwordless for members of the sudo group"
        else
            echo "Sudo: password required"
        fi
        echo
        echo "The script installs and configures its complete terminal toolset,"
        echo "services, shell environment, Neovim starter, and tmux configuration."
        echo "It supports Debian, Ubuntu, Kali, Devuan, and related APT systems."
    } > "$review_file"
    tui_text "Provision Review" "$review_file" || true
}

script_provision_configure() {
    local choice value selected
    while true; do
        choice=$(tui_menu "Configure Provision Script" "Settings passed to the bundled provision script:" \
            timezone "Timezone: $SCRIPT_PROV_TZ" \
            username "Primary login: $SCRIPT_PROV_USER" \
            hostname "Hostname: $SCRIPT_PROV_HOST" \
            sudo "Sudo policy: $([ "$SCRIPT_PROV_NOPASS" = 1 ] && echo passwordless || echo password-required)" \
            review "Review current settings" \
            reset "Reset to script defaults" \
            back "Save and return") || { script_provision_save; return 0; }
        case "$choice" in
            timezone)
                value=$(tui_input "Timezone" "Timezone (for example America/New_York or UTC)" "$SCRIPT_PROV_TZ") || continue
                case "$value" in
                    ''|*[!a-zA-Z0-9_+./-]*)
                        tui_msg "Invalid Timezone" "Use a tzdata name such as America/New_York or UTC."
                        ;;
                    *) SCRIPT_PROV_TZ="$value" ;;
                esac
                ;;
            username)
                value=$(tui_input "Primary Login" "Existing or new username" "$SCRIPT_PROV_USER") || continue
                case "$value" in
                    ''|root) tui_msg "Invalid Username" "Enter a non-root username." ;;
                    *[!a-zA-Z0-9_.-]*|[0-9]*|[-.]*)
                        tui_msg "Invalid Username" "Use letters, numbers, underscore, dot, or hyphen; do not start with a number, dot, or hyphen."
                        ;;
                    *) SCRIPT_PROV_USER="$value" ;;
                esac
                ;;
            hostname)
                value=$(tui_input "Hostname" "Hostname to configure" "$SCRIPT_PROV_HOST") || continue
                case "$value" in
                    ''|*[!a-zA-Z0-9.-]*|.*|-*|*.)
                        tui_msg "Invalid Hostname" "Use letters, numbers, dots, and hyphens."
                        ;;
                    *) SCRIPT_PROV_HOST="$value" ;;
                esac
                ;;
            sudo)
                selected=$(tui_radio "Sudo Policy" "Choose how sudo authenticates:" \
                    password "Require the user's password" $([ "$SCRIPT_PROV_NOPASS" = 0 ] && echo on || echo off) \
                    nopass "Allow passwordless sudo" $([ "$SCRIPT_PROV_NOPASS" = 1 ] && echo on || echo off)) || continue
                [ "$selected" = nopass ] && SCRIPT_PROV_NOPASS=1 || SCRIPT_PROV_NOPASS=0
                ;;
            review) script_provision_review ;;
            reset)
                if tui_yesno "Reset Settings" "Reset all provision-script settings to their defaults?"; then
                    unset SCRIPT_PROV_TZ SCRIPT_PROV_USER SCRIPT_PROV_HOST SCRIPT_PROV_NOPASS
                    script_provision_defaults
                fi
                ;;
            back) script_provision_save; return 0 ;;
        esac
        script_provision_save
    done
}

script_provision_run() {
    local script="$LIBDIR/src/provision/provision-system.sh" rc=0
    [ -r "$script" ] || {
        tui_msg "Provision Script Missing" "The bundled provision script was not found at:\n$script"
        return 0
    }
    if ! command -v apt-get >/dev/null 2>&1; then
        tui_msg "Unsupported System" "This provision script requires an APT-based Debian, Ubuntu, Kali, Devuan, or related system."
        return 0
    fi
    script_provision_review
    tui_yesno "Confirm Provisioning" "Run the bundled provision script now?\n\nThis installs packages and changes system-wide configuration." || return 0
    script_provision_save
    clear
    if env TZ_NAME="$SCRIPT_PROV_TZ" \
        TARGET_USER="$SCRIPT_PROV_USER" \
        NEW_HOSTNAME="$SCRIPT_PROV_HOST" \
        SUDO_NOPASS="$SCRIPT_PROV_NOPASS" \
        sh "$script"; then
        rc=0
    else
        rc=$?
    fi
    echo
    if [ "$rc" -eq 0 ]; then
        echo "Provisioning completed successfully."
    else
        echo "Provisioning failed with status $rc."
    fi
    read -rp "Press Enter to return to systui..." _ || true
    return 0
}

menu_provision_system() {
    local choice
    script_provision_load
    while true; do
        choice=$(tui_menu "Provision System" \
            "Configure and run the bundled Debian-family terminal provision script." \
            configure "Configure script settings" \
            review "Review settings and detected system" \
            run "Run provision script" \
            back "Back to main menu") || return 0
        case "$choice" in
            configure) script_provision_configure ;;
            review) script_provision_review ;;
            run) script_provision_run ;;
            back) return 0 ;;
        esac
    done
}

export -f menu_provision_system
