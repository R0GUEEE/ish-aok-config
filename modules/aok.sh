#!/bin/sh

aok_build_manage_menu(){
  while :; do
    c=$(ui_menu 'AOK: Build and manage' "Active rootfs: $(active_rootfs)" \
      studio 'Builder Studio and build queue' \
      builders 'Build or import a rootfs' \
      filesystems 'Clone, archive and manage rootfs filesystems' \
      snapshots 'Snapshots and rollback') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      studio) aok_builder_studio;;
      builders) aok_build_menu;;
      filesystems) aok_filesystems_menu;;
      snapshots) aok_snapshots_menu;;
    esac
  done
}

aok_chroot_repair_menu(){
  while :; do
    c=$(ui_menu 'AOK: Chroot and repair' "Active rootfs: $(active_rootfs)" \
      chroot 'Enter chroot and manage mounts' \
      state 'Repair build state' \
      packages 'Repair architecture and packages' \
      integrity 'Integrity and filesystem repair') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      chroot) aok_chroot_menu;;
      state) aok_repair_menu;;
      packages) aok_arch_packages_menu;;
      integrity) aok_advanced_tools_menu;;
    esac
  done
}

aok_configure_menu(){
  while :; do
    c=$(ui_menu 'AOK: Configure and optimize' "Active rootfs: $(active_rootfs)" \
      repos 'Repositories, init and SSH' \
      optimize 'Optimize and synchronize' \
      automation 'Batch and automation tools' \
      mounts 'Saved rootfs mount profiles') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      repos) aok_repos_init_ssh_menu;;
      optimize) aok_optimize_sync_menu;;
      automation) aok_more_options_menu;;
      mounts) mount_rootfs_profiles_menu 2>/dev/null || mount_manager_menu;;
    esac
  done
}

aok_advanced_menu(){
  while :; do
    c=$(ui_menu 'AOK: Advanced tools' "Active rootfs: $(active_rootfs)" \
      preflight 'Preflight and compatibility checks' \
      diagnostics 'Diagnostics and reports' \
      developer 'Developer and Git tools' \
      report 'Generate environment report' \
      settings 'AOK settings file') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      preflight) aok_advanced_tools_menu;;
      diagnostics) aok_diagnostics_menu;;
      developer) aok_developer_menu;;
      report) aok_environment_report;;
      settings) edit_file "$AOK_STATE_DIR/settings.conf";;
    esac
  done
}

# Compatibility wrappers retained for old callers.
aok_enter_mount_menu(){ aok_chroot_repair_menu; }
aok_repair_integrity_menu(){ aok_chroot_repair_menu; }
aok_config_services_menu(){ aok_configure_menu; }
aok_backup_developer_menu(){ aok_advanced_menu; }

aok_menu(){
  while :; do
    c=$(ui_menu 'iSH-AOK and RootFS' "Active rootfs: $(active_rootfs)\nChoose a task. Destructive actions require confirmation." \
      platform 'v8 RootFS Platform' \
      workflows 'Workflow Edition' \
      studios 'RootFS studios' \
      context 'Dashboard and select rootfs' \
      build 'Build and manage rootfs' \
      repair 'Chroot and repair' \
      configure 'Configure and optimize' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      platform) platform_v80_menu;;
      workflows) aok_v71_workflows_menu;;
      studios) aok_v7_studios_menu;;
      context) aok_context_menu;;
      build) aok_build_manage_menu;;
      repair) aok_chroot_repair_menu;;
      configure) aok_configure_menu;;
      advanced) aok_advanced_menu;;
    esac
  done
}
