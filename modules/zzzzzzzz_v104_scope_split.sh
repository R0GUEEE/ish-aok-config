#!/bin/sh
# v10.4 strict separation between RootFS operations and running-system configuration.

v104_context_get(){ active_rootfs 2>/dev/null || printf '/'; }

# Run an existing configuration handler against the live system only. The
# previously selected RootFS is restored even when the handler returns nonzero.
v104_main_scope_call(){
  handler=$1; shift
  previous=$(v104_context_get)
  set_active_rootfs / || return 1
  "$handler" "$@"
  rc=$?
  [ "$previous" = / ] || set_active_rootfs "$previous" >/dev/null 2>&1 || true
  return "$rc"
}

v104_system_status(){
  printf 'Target: running iSH-AOK system (/).\n'
  printf 'Distribution: %s\nArchitecture: %s\nPackage manager: %s\nInit system: %s\n' \
    "${DISTRO_ID:-unknown}" "${ARCH:-unknown}" "${PKG_MGR:-unknown}" "${INIT_SYSTEM:-unknown}"
  selected=$(v104_context_get)
  [ "$selected" != / ] && printf '\nSelected RootFS remains separate: %s\n' "$selected"
}

v104_system_packages_menu(){
  while :; do
    choice=$(ui_menu 'System Packages' 'These actions affect packages and repositories on the running iSH-AOK system only.' \
      packages 'Manage installed packages' \
      repositories 'Package repositories' \
      update 'Refresh package indexes' \
      upgrade 'Upgrade installed packages' \
      back 'Back') || return 0
    case $choice in
      packages) v104_main_scope_call package_menu;;
      repositories) v104_main_scope_call repositories_menu;;
      update) v104_main_scope_call run_capture 'Package index update' pkg_update;;
      upgrade) v104_main_scope_call run_capture 'System package upgrade' pkg_upgrade;;
      back) return 0;;
    esac
  done
}

v104_system_configuration_menu(){
  while :; do
    choice=$(ui_menu 'System Configuration' "$(v104_system_status)\nThese actions affect only the running system, never the selected RootFS." \
      packages 'Packages and repositories' \
      services 'Services and startup' \
      users 'Users, passwords and sudo' \
      shells 'Shells, prompts and terminal' \
      editors 'Editors and editor configuration' \
      network 'Networking, DNS and SSH' \
      storage 'Storage, mounts and backups' \
      performance 'Performance and maintenance' \
      health 'System health and diagnostics' \
      advanced 'Advanced system tools' \
      back 'Back') || return 0
    case $choice in
      packages) v104_system_packages_menu;;
      services) v104_main_scope_call service_center_v6;;
      users) v104_main_scope_call users_menu;;
      shells) v104_main_scope_call shells_menu;;
      editors) v104_main_scope_call editors_menu;;
      network) v104_main_scope_call v1052_network_menu;;
      storage) v104_main_scope_call v1052_storage_menu;;
      performance) v104_main_scope_call performance_menu;;
      health) v104_main_scope_call monitoring_recovery_menu;;
      advanced) v104_main_scope_call v1052_advanced_system_menu;;
      back) return 0;;
    esac
  done
}

v104_select_target_rootfs(){
  target=$(v104_context_get)
  if [ "$target" = / ] || [ ! -d "$target" ]; then
    ui_msg 'Select a RootFS' 'Choose the RootFS that you want to edit. System Configuration is used for the running system.'
    rootfs_select_anywhere || rootfs_registry_select_ui || return 1
    target=$(v104_context_get)
  fi
  [ "$target" != / ] && [ -d "$target" ] || {
    ui_msg 'RootFS required' 'The running system cannot be edited from RootFS Builder. Select a separate RootFS directory.'
    return 1
  }
}

v104_edit_existing_rootfs(){
  v104_select_target_rootfs || return
  target=$(v104_context_get)
  while :; do
    choice=$(ui_menu 'Edit Existing RootFS' "Target RootFS: $target\nAll actions on this screen affect this RootFS only." \
      select 'Choose another RootFS' \
      identity 'Hostname, locale and timezone' \
      users 'Users, passwords and sudo' \
      shells 'Shells and prompts inside RootFS' \
      editors 'Editors inside RootFS' \
      packages 'Packages and repositories inside RootFS' \
      services 'Services and boot configuration inside RootFS' \
      network 'Networking, DNS and SSH inside RootFS' \
      health 'Validate and repair RootFS' \
      enter 'Enter RootFS shell' \
      back 'Back') || return 0
    case $choice in
      select) rootfs_select_anywhere || rootfs_registry_select_ui; target=$(v104_context_get); [ "$target" != / ] || return;;
      identity) system_menu;;
      users) users_menu;;
      shells) shell_wizards_menu;;
      editors) editors_menu;;
      packages) rootfs_package_native;;
      services) service_center_v6;;
      network) network_center;;
      health) v103_health_dashboard;;
      enter) rootfs_chroot_studio;;
      back) return 0;;
    esac
  done
}

# Compatibility name used by the v11 builder and RootFS management menus.
v104_manage_rootfs_menu(){ v104_edit_existing_rootfs; }

v104_builder_help(){
  ui_text 'RootFS Builder Help' 'RootFS Builder is only for creating or changing filesystem trees that are separate from the running system.

Create a New RootFS guides you through distribution, architecture, build type, source, destination and validation.

Edit an Existing RootFS selects a target directory before exposing configuration tools. Shell, editor, package, service and network changes made there are written inside that RootFS.

Current Build reviews or resumes one build.

More Build Options contains only reusable profiles, direct bootstrap backends, logs and recovery. Build studios, matrices, recipes, queues and project abstractions are not part of the normal interface.

Use System Configuration from the main menu to change the running iSH-AOK environment.'
}

v104_about(){
  selected=$(v104_context_get)
  ui_text 'About iSH-AOK Config' "iSH-AOK Config $VERSION

RootFS Builder target: $selected
System Configuration target: /

RootFS and host configuration are isolated by design.
Distribution: ${DISTRO_ID:-unknown}
Architecture: ${ARCH:-unknown}
Init system: ${INIT_SYSTEM:-unknown}

Project: https://github.com/emkey1/ish-AOK"
}

# Friendlier titles and status text for the separated interface.
v91_menu_title(){
  case $1 in
    main) printf '%s %s' "$PROGRAM" "$VERSION";;
    build) printf 'RootFS Builder';;
    build_advanced) printf 'More Build Options';;
    rootfs*) printf 'RootFS Tools';;
    settings*) printf 'Settings';;
    *) printf '%s' "$1";;
  esac
}

v91_menu_text(){
  case $1 in
    main) printf 'Choose whether to work on a RootFS or configure the running system.';;
    build) printf 'Target: separate RootFS filesystems only.\nSelected RootFS: %s' "$(v104_context_get)";;
    build_advanced) printf 'Optional build profiles, direct backends and recovery.';;
    settings*) printf 'Application behavior only; these settings do not configure a RootFS.';;
    *) printf 'Select an action.';;
  esac
}

# Compatibility redirects: old project/studio landing functions now open the
# appropriate streamlined builder rather than exposing retired dashboards.
v90_build_workflow_menu(){ v91_menu_run build; }
unified_build_menu(){ v91_menu_run build; }
v102_simple_builder_menu(){ v91_menu_run build; }
v1000_task_center_menu(){ main_menu; }
