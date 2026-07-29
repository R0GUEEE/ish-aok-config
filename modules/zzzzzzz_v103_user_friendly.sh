#!/bin/sh
# v10.3 user-friendly interface and guided workflows.

V103_PREFS=${STATE_DIR}/usability-v103.conf
V103_MODE=simple
[ -r "$V103_PREFS" ] && . "$V103_PREFS" || true

v103_save_mode(){ mkdir -p "$STATE_DIR"; printf 'V103_MODE=%s\n' "$V103_MODE" >"$V103_PREFS"; }
v103_mode_menu(){
  c=$(ui_radiolist 'Interface mode' 'Simple mode shows recommended choices. Advanced mode exposes every tool.' simple 'Simple — recommended' "$([ "$V103_MODE" = simple ] && echo on || echo off)" advanced 'Advanced — all controls' "$([ "$V103_MODE" = advanced ] && echo on || echo off)") || return
  V103_MODE=$c; v103_save_mode; ui_msg 'Interface mode' "Mode changed to: $V103_MODE"
}

v103_detect_report(){
  root=$(active_rootfs 2>/dev/null || printf none)
  printf 'Detected environment\n\n'
  printf 'RootFS:        %s\n' "$root"
  printf 'Distribution: %s\n' "${DISTRO_ID:-unknown}"
  printf 'Architecture: %s\n' "${ARCH:-unknown}"
  printf 'Package tool: %s\n' "${PKG_MGR:-unknown}"
  printf 'Init system:  %s\n' "${INIT_SYSTEM:-unknown}"
  printf 'iSH-AOK:      %s\n' "${AOK_DETECTED:-no}"
  command -v debootstrap >/dev/null 2>&1 && printf 'debootstrap:  available\n' || printf 'debootstrap:  not installed\n'
  command -v apk >/dev/null 2>&1 && printf 'apk:          available\n' || true
  command -v pacstrap >/dev/null 2>&1 && printf 'pacstrap:     available\n' || true
  command -v dnf >/dev/null 2>&1 && printf 'dnf:          available\n' || true
  command -v xbps-install >/dev/null 2>&1 && printf 'xbps:         available\n' || true
}

v103_quick_profile_apply(){
  p=$1
  v93_profile_defaults_extend
  case $p in
    minimal) packages='bash ca-certificates curl';;
    standard) packages='bash bash-completion ca-certificates curl wget sudo nano openssh-client';;
    developer) packages='bash bash-completion ca-certificates curl wget git build-essential cmake gdb python3 python3-pip python3-venv neovim openssh-client openssh-server sudo';;
    server) packages='bash ca-certificates curl openssh-client openssh-server sudo cron logrotate rsyslog';;
    build) packages='bash ca-certificates curl wget git build-essential cmake pkg-config file patch tar xz-utils';;
    recovery) packages='bash coreutils findutils grep sed gawk diffutils util-linux procps file less curl wget tar gzip xz-utils';;
    *) return 1;;
  esac
  v87_profile_set "$V87_BUILD_PROFILE" PACKAGES "$packages"
  v87_profile_set "$V87_BUILD_PROFILE" PROFILE "$p"
  ui_msg 'Quick profile' "Applied the $p profile. You can review every setting before building."
}

v103_quick_profiles_menu(){
  while :; do
    c=$(ui_menu 'Quick Setup Profiles' 'Choose a practical starting point. Settings remain editable.' minimal 'Minimal — smallest usable shell environment' standard 'Standard — everyday command-line system' developer 'Developer Workstation — compilers, Git, Python and editors' server 'Server — SSH, logging and scheduled tasks' build 'Build Environment — compilation and packaging tools' recovery 'Recovery Environment — repair and archive utilities' custom 'Custom — configure packages manually' back 'Back') || return 0
    case $c in
      minimal|standard|developer|server|build|recovery) v103_quick_profile_apply "$c"; return;;
      custom) v87_profile_choose_packages; return;; back) return;;
    esac
  done
}

v103_build_review(){ ui_text 'Current build' "$(v102_build_summary)"; v102_current_build_menu; }
v103_builder_help(){ ui_text 'Builder help' 'Guided Build asks only for the distribution, architecture, build style, destination and confirmation.

Minimal creates the smallest useful system.
Standard adds common interactive tools.
Developer adds compilers, Git, Python and editors.
Server adds SSH and maintenance services.
Custom exposes package selection.

Advanced Builder contains profiles, matrices, direct backends, queues and recovery tools.'; }

v103_build_new(){
  ui_text 'Welcome' 'This wizard creates a new RootFS using recommended defaults. Cancel or Back returns without starting a build.'
  ui_text 'Automatic detection' "$(v103_detect_report)"
  v87_profile_choose_distro || return
  v87_profile_choose_arch || return
  p=$(ui_radiolist 'Build type' 'Choose how the RootFS will be used.' minimal 'Minimal' off standard 'Standard — recommended' on developer 'Developer Workstation' off server 'Server' off build 'Build Environment' off recovery 'Recovery Environment' off custom 'Custom package selection' off) || return
  [ "$p" = custom ] && v87_profile_choose_packages || v103_quick_profile_apply "$p"
  v93_profile_source_select || return
  v92_profile_location_select || return
  if ui_yesno 'Configure now' 'Set hostname, user, init system, shell and optional features before building?'; then
    v92_profile_choose_identity || return
    v87_profile_choose_init_shell || return
    [ "$V103_MODE" = advanced ] && v87_profile_choose_options || true
  fi
  ui_text 'Ready to build' "$(v102_build_summary)\n\nThe build will not start until you confirm."
  v87_profile_validate || { ui_msg 'Validation failed' 'Review the highlighted settings and try again.'; return 1; }
  ui_yesno 'Start build' 'Validation passed. Start building this RootFS now?' || return 0
  v88_execute_plan
}

v103_configure_rootfs(){
  root=$(active_rootfs 2>/dev/null || true)
  [ -n "$root" ] && [ "$root" != / ] || { ui_msg 'Select a RootFS' 'Choose an existing RootFS before configuring it.'; rootfs_select_anywhere || rootfs_registry_select_ui; root=$(active_rootfs 2>/dev/null || true); }
  [ -n "$root" ] || return 1
  ui_text 'Configure RootFS' "Active RootFS: $root\n\nThe wizard will guide you through common settings one section at a time."
  while :; do
    c=$(ui_menu 'Configure a RootFS' "Active: $root" identity 'Hostname, locale and timezone' users 'Users, passwords and sudo' shell 'Shell, prompt and terminal' editor 'Default editor and editor configuration' network 'Networking, DNS and repositories' ssh 'SSH server and remote access' packages 'Recommended software' advanced 'Advanced configuration tools' back 'Back') || return 0
    case $c in
      identity) system_menu;; users) users_menu;; shell) shell_wizards_menu;; editor) editors_menu;; network) network_center;; ssh) ssh_menu;; packages) rootfs_package_native;; advanced) system_menu;; back) return;;
    esac
  done
}

v103_typed_confirm(){
  title=$1; subject=$2; token=${3:-DELETE}
  got=$(ui_input "$title" "$subject\n\nType $token to continue." '') || return 1
  [ "$got" = "$token" ] || { ui_msg 'Cancelled' 'The confirmation text did not match. Nothing was changed.'; return 1; }
}

v103_fix_rootfs(){
  while :; do
    c=$(ui_menu 'Fix My RootFS' 'Choose the closest problem. Diagnostics run before any repair action.' boot "RootFS won't start or enter" apt 'apt, apk, pacman, dnf or xbps does not work' dns 'DNS or Internet access is broken' ssh 'SSH will not start or accept connections' locale 'Locale or timezone problems' packages 'Missing or broken packages' permissions 'Broken ownership or permissions' full 'Run complete health diagnostics' back 'Back') || return 0
    case $c in
      boot) rootfs_repair_studio;; apt|packages) rootfs_package_native;; dns) network_center;; ssh) ssh_menu;; locale) system_menu;; permissions) security_tools_menu;; full) rootfs_health_report;; back) return;;
    esac
  done
}

v103_maintenance_menu(){
  while :; do
    c=$(ui_menu 'System Maintenance' 'Common repairs are grouped here.' fix 'Fix My RootFS wizard' packages 'Package maintenance' services 'Service and boot management' storage 'Storage, mounts and backups' network 'Networking, DNS and SSH' cleanup 'Safe cleanup' advanced 'Advanced maintenance tools' back 'Back') || return 0
    case $c in fix) v103_fix_rootfs;; packages) rootfs_package_native;; services) service_center_v6;; storage) storage_backup_menu;; network) network_center;; cleanup) rootfs_safe_cleanup;; advanced) system_menu;; back) return;; esac
  done
}

# Friendlier settings landing screen while preserving advanced settings.
v103_settings_menu(){
  while :; do
    c=$(ui_menu 'Settings' "Interface mode: $V103_MODE" mode 'Simple or Advanced interface mode' defaults 'Application defaults' ui 'Terminal UI and display settings' favorites 'Favorites and search' advanced 'Advanced settings' help 'Help and keyboard behavior' back 'Back') || return 0
    case $c in mode) v103_mode_menu;; defaults) project_settings_menu;; ui) ui_mode_menu;; favorites) v990_navigation_search_menu;; advanced) v91_menu_run settings_advanced;; help) ui_text Help 'Enter selects an item. Escape or Cancel returns to the previous menu. Every normal operation asks for confirmation before destructive changes. Search finds advanced tools that are not shown in Simple mode.';; back) return;; esac
  done
}


v103_settings_help(){ ui_text Help 'Enter selects an item. Escape or Cancel returns to the previous menu. Destructive actions require confirmation. Search can find advanced tools hidden from the simple main menu.'; }
