#!/bin/sh

V90_CONTEXT_DIR=${V90_CONTEXT_DIR:-$STATE_DIR/workspace-v90}
V90_CONTEXT_FILE=$V90_CONTEXT_DIR/context.conf
mkdir -p "$V90_CONTEXT_DIR" 2>/dev/null || true

v90_context_set(){ session_save "v90_$1" "$2"; }
v90_context_get(){ session_get "v90_$1"; }
v90_active_rootfs(){ r=$(active_rootfs 2>/dev/null || true); [ -n "$r" ] && printf '%s' "$r" || printf '/'; }
v90_active_profile_name(){
  command -v v87_profile_defaults >/dev/null 2>&1 && v87_profile_defaults >/dev/null 2>&1 || true
  n=$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME 2>/dev/null || true)
  [ -n "$n" ] && printf '%s' "$n" || printf 'not configured'
}
v90_active_project(){ p=$(v90_context_get project); [ -n "$p" ] && printf '%s' "$p" || printf 'not selected'; }
v90_build_status(){
  command -v v88_current_run >/dev/null 2>&1 || { printf 'idle'; return; }
  run=$(v88_current_run)
  [ -n "$run" ] || { printf 'idle'; return; }
  [ -d "$V88_RUN_DIR/$run" ] || { printf 'idle'; return; }
  failed=$(find "$V88_RUN_DIR/$run" -name '*.state' -type f -exec grep -l '^failed$' {} \; 2>/dev/null | head -n 1)
  [ -n "$failed" ] && { printf 'failed (%s)' "$run"; return; }
  running=$(find "$V88_RUN_DIR/$run" -name '*.state' -type f -exec grep -l '^running$' {} \; 2>/dev/null | head -n 1)
  [ -n "$running" ] && { printf 'running (%s)' "$run"; return; }
  printf 'saved (%s)' "$run"
}
v90_workspace_summary(){
  root=$(v90_active_rootfs)
  distro=$DISTRO_ID; arch=$ARCH; init=$INIT_SYSTEM; pkg=$PKG_MGR
  if [ "$root" != / ] && [ -d "$root" ]; then
    command -v rootfs_registry_refresh >/dev/null 2>&1 && rootfs_registry_refresh "$root" >/dev/null 2>&1 || true
    d=$(rootfs_meta_get "$root" distro 2>/dev/null || true); [ -n "$d" ] && distro=$d
    a=$(rootfs_meta_get "$root" arch 2>/dev/null || true); [ -n "$a" ] && arch=$a
    i=$(rootfs_meta_get "$root" init 2>/dev/null || true); [ -n "$i" ] && init=$i
    p=$(rootfs_meta_get "$root" package_manager 2>/dev/null || true); [ -n "$p" ] && pkg=$p
  fi
  printf 'Active RootFS: %s\nDistribution: %s\nArchitecture: %s\nInit: %s\nPackage manager: %s\nActive project: %s\nBuild profile: %s\nBuild status: %s\nNotifications: %s unread\n' \
    "$root" "$distro" "$arch" "$init" "$pkg" "$(v90_active_project)" "$(v90_active_profile_name)" "$(v90_build_status)" "$(notification_unread_count)"
}

v90_select_project(){
  command -v rootfs_project_select >/dev/null 2>&1 || { ui_msg Projects 'Project support is unavailable.'; return 1; }
  id=$(rootfs_project_select) || return
  v90_context_set project "$id"
  f=$(v80_project_file "$id" 2>/dev/null || true)
  if [ -f "$f" ]; then r=$(v80_conf_get "$f" rootfs); [ -d "$r" ] && set_active_rootfs "$r"; fi
  activity_add workspace "Selected project $id"
}

v90_context_menu(){
  while :; do
    c=$(ui_menu 'Workspace context' "$(v90_workspace_summary)" rootfs 'Select registered RootFS' anywhere 'Select RootFS from anywhere' project 'Select active project' profile 'Select or configure build profile' clear_project 'Clear active project' session 'Session restore') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      rootfs) rootfs_registry_browser;;
      anywhere) rootfs_select_anywhere;;
      project) v90_select_project;;
      profile) v89_profile_manager_menu;;
      clear_project) v90_context_set project '';;
      session) workspace_session_menu;;
    esac
  done
}

v90_rootfs_actions_menu(){
  while :; do
    c=$(ui_menu 'RootFS Explorer' "Active: $(v90_active_rootfs)" select 'Select registered RootFS' anywhere 'Select RootFS from anywhere' enter 'Enter with Chroot Studio' configure 'Configure active RootFS' packages 'Manage packages' services 'Manage services and boot' snapshot 'Create or browse snapshots' repair 'Repair active RootFS' clone 'Clone RootFS' compare 'Compare RootFS instances' export 'Archive or export RootFS' reports 'Health and compatibility reports' projects 'RootFS projects') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      select) rootfs_registry_browser;; anywhere) rootfs_select_anywhere;; enter) rootfs_chroot_studio;; configure) aok_v7_studios_menu;; packages) rootfs_package_native;; services) v85_service_orchestration_menu;; snapshot) aok_snapshots_menu;; repair) rootfs_repair_studio;; clone) rootfs_manager_clone;; compare) advanced_rootfs_diff_menu_v72;; export) rootfs_import_export_studio;; reports) rootfs_reports_studio;; projects) rootfs_projects_menu;;
    esac
  done
}

v90_build_workflow_menu(){
  while :; do
    c=$(ui_menu 'Unified Build Studio' "Profile: $(v90_active_profile_name)\nStatus: $(v90_build_status)" preset 'Choose distribution preset' configure 'Customize build profile' validate 'Validate profile and preflight' plan 'Review staged build plan' execute 'Execute or resume build' monitor 'Build status and logs' queue 'Build recipes and queue' projects 'RootFS projects' advanced 'Advanced builder backends') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      preset) v89_profile_apply_preset;; configure) v87_build_profile_wizard;; validate) ui_text 'Build profile validation' "$(v89_profile_validate_report)";; plan) ui_text 'Build plan' "$(v88_build_plan_report)";; execute) v88_build_execution_menu;; monitor) v88_build_execution_menu;; queue) v89_recipes_queue_menu;; projects) rootfs_projects_menu;; advanced) v87_manual_builders_menu;;
    esac
  done
}

v90_administration_menu(){
  while :; do
    c=$(ui_menu Administration 'System, software, user, storage and recovery administration.' software 'Software and development' system 'System administration' user 'User environment' storage 'Storage, network and backups' recovery 'Monitoring and recovery') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in software) software_development_menu;; system) system_admin_menu;; user) user_interface_menu;; storage) storage_network_menu;; recovery) monitoring_recovery_menu;; esac
  done
}

v90_reports_menu(){
  while :; do
    c=$(ui_menu Reports 'Generate and review workspace and RootFS reports.' workspace 'Workspace report' rootfs 'RootFS reports studio' health 'Health dashboard' compatibility 'Compatibility analysis' distribution 'Distribution report' services 'Service report' repositories 'Repository report' platform 'Platform report') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in workspace) ui_text 'Workspace report' "$(workspace_report_v90)";; rootfs) rootfs_reports_studio;; health) rootfs_health_interactive;; compatibility) compatibility_deep_report_v72;; distribution) root=$(v90_active_rootfs); ui_text Distribution "$(cat "$(v84_distribution_report "$root")")";; services) root=$(v90_active_rootfs); ui_text Services "$(cat "$(service_v85_report "$root")")";; repositories) root=$(v90_active_rootfs); ui_text Repositories "$(cat "$(repo_v86_report "$root")")";; platform) ui_text Platform "$(platform_v80_report)";; esac
  done
}

v90_settings_menu(){
  while :; do
    c=$(ui_menu Settings 'Workspace and application settings.' context 'Workspace context' workspace 'Workspace preferences' setup 'Setup and profiles' plugins 'Plugin and Module SDK' classic 'Classic navigation') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in context) v90_context_menu;; workspace) workspace_settings_menu;; setup) setup_profiles_menu;; plugins) sdk_center;; classic) classic_main_menu;; esac
  done
}

workspace_dashboard_v90(){
  while :; do
    c=$(ui_menu "$PROGRAM $VERSION — Unified Workspace" "$(v90_workspace_summary)" palette 'Search all commands' rootfs 'RootFS Explorer' build 'Unified Build Studio' projects 'Projects and multi-RootFS' automation 'Workflows and automation' admin 'Administration' reports 'Reports' context 'Change workspace context' recent 'Recent actions' notifications 'Notifications' settings 'Settings' classic 'Classic Navigation' refresh 'Refresh workspace' exit 'Exit') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      palette) workspace_command_palette;; rootfs) v90_rootfs_actions_menu;; build) v90_build_workflow_menu;; projects) platform_v80_menu;; automation) workflow_engine_menu;; admin) v90_administration_menu;; reports) v90_reports_menu;; context) v90_context_menu;; recent) workspace_recent_menu;; notifications) workspace_notifications_menu;; settings) v90_settings_menu;; classic) classic_main_menu;; refresh) detect_system; scan_system >/dev/null 2>&1 || true;; exit) return;;
    esac
  done
}

rootfs_chroot_studio(){ chroot_studio_menu; }
main_menu(){ workspace_dashboard_v90; }
workspace_report_v90(){ command_registry_build; printf 'iSH-AOK Workspace — Unified Workspace\n\n%s\nRegistered actions: %s\n' "$(v90_workspace_summary)" "$(awk 'END{print NR+0}' "$V73_ACTIONS_FILE")"; awk -F '\t' '{printf "%-20s %-14s %s\n",$1,$3,$2}' "$V73_ACTIONS_FILE"; }
