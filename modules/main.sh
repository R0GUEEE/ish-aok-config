#!/bin/sh

setup_profiles_menu(){
  while :; do
    c=$(ui_menu 'Setup and profiles' 'Prepare a new system, apply a profile, or change project behavior.' \
      quick 'Quick system setup' \
      profiles 'Configuration profiles' \
      settings 'Project settings' \
      rescan 'Rescan system') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      quick) quick_system_setup_menu;;
      profiles) configuration_profiles_center;;
      settings) project_settings_menu;;
      rescan) scan_system; ui_msg 'System scan' "Updated inventory for $DISTRO_ID ($ARCH).";;
    esac
  done
}

software_development_advanced_menu(){
  while :; do
    c=$(ui_menu 'Software and development: Advanced tools' 'Less frequently used package, build and automation tools.' \
      repos 'Repositories and mirrors' \
      bundles 'Package bundles and reusable profiles' \
      toolconfig 'Additional tool configuration wizards' \
      languages 'Language ecosystems and toolchains' \
      build 'Build systems and compilers' \
      containers 'Containers, proot and isolation' \
      workflows 'Workflow Engine' \
      sdk 'Module and Plugin SDK' \
      reliability 'Architecture and reliability' \
      operations 'Operations hardening and integrity' \
      distribution 'Distribution integration and compatibility' \
      services85 'Service and boot orchestration' \
      repository86 'Repository and package policy' \
      automation 'Hooks and automation helpers') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      repos) repositories_menu;;
      bundles) profiles_bundles_menu;;
      toolconfig) tool_config_menu;;
      languages) languages_menu;;
      build) build_compilers_menu;;
      containers) container_center;;
      workflows) workflow_engine_menu;;
      sdk) sdk_center;;
      reliability) v82_reliability_menu;;
      operations) v83_operations_menu;;
      distribution) v84_distribution_integration_menu;;
      services85) v85_service_orchestration_menu;;
      repository86) v86_repository_policy_menu;;
      automation) profiles_bundles_menu;;
    esac
  done
}

software_development_menu(){
  while :; do
    c=$(ui_menu 'Software and development' 'Install software, manage plugins, and configure development tools.' \
      packages 'Packages: install, remove and repair' \
      plugins 'Plugins and frameworks' \
      developer 'Developer tools' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      packages) package_center_v6;;
      plugins) plugin_marketplace_center;;
      developer) developer_center_v6;;
      advanced) software_development_advanced_menu;;
    esac
  done
}

system_admin_advanced_menu(){
  while :; do
    c=$(ui_menu 'System administration: Advanced tools' 'Advanced service, scheduling and logging operations.' \
      init 'Init system and SysVinit/OpenRC' \
      orchestration 'Service and boot orchestration' \
      scheduler 'Cron, at and scheduled jobs' \
      logging 'Logging and rotation' \
      security 'Security audits and integrity') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      init) init_system_menu;;
      orchestration) v85_service_orchestration_menu;;
      scheduler) scheduler_center;;
      logging) logging_center_v6;;
      security) security_center_v6;;
    esac
  done
}

system_admin_menu(){
  while :; do
    c=$(ui_menu 'System administration' 'Manage system identity, services, users and administrator access.' \
      identity 'Locale, timezone and hostname' \
      services 'Services' \
      users 'Users and permissions' \
      privilege 'Sudo and doas' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      identity) system_menu;;
      services) service_center_v6;;
      users) users_permissions_center;;
      privilege) privilege_admin_menu;;
      advanced) system_admin_advanced_menu;;
    esac
  done
}

user_environment_advanced_menu(){
  while :; do
    c=$(ui_menu 'User environment: Advanced tools' 'Themes, navigation utilities, dotfiles and direct configuration wizards.' \
      themes 'Themes and appearance' \
      search 'Search and navigation tools' \
      configs 'Configuration-file wizards' \
      dotfiles 'Dotfiles and managed blocks') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      themes) theme_center;;
      search) search_tools_menu;;
      configs) config_files_menu;;
      dotfiles) dotfiles_hooks_menu;;
    esac
  done
}

user_interface_menu(){
  while :; do
    c=$(ui_menu 'User environment' 'Configure shells, editors, terminals and file managers.' \
      shells 'Shells and prompts' \
      editors 'Editors' \
      terminal 'Terminal, tmux and Screen' \
      files 'File managers' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      shells) shell_center_v6;;
      editors) editor_center_v6;;
      terminal) terminal_center_v6;;
      files) file_manager_center_v6;;
      advanced) user_environment_advanced_menu;;
    esac
  done
}

storage_network_advanced_menu(){
  while :; do
    c=$(ui_menu 'Storage and network: Advanced tools' 'Advanced filesystem, archive and network utilities.' \
      compression 'Compression and archives' \
      rootfs 'RootFS Build Studio' \
      nettools 'Network diagnostic and transfer tools' \
      security 'Security audits and secret scanning') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      compression) compression_menu;;
      rootfs) aok_builder_studio;;
      nettools) network_tools_menu;;
      security) security_center_v6;;
    esac
  done
}

storage_network_menu(){
  while :; do
    c=$(ui_menu 'Storage, network and backups' 'Manage disks, mounts, backups, networking and SSH.' \
      storage 'Disks and filesystems' \
      mounts 'Mounts and bind mounts' \
      backup 'Backup and restore' \
      network 'Network and DNS' \
      ssh 'SSH and remote access' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      storage) storage_center_v6;;
      mounts) mount_manager_menu;;
      backup) backup_restore_center;;
      network) network_center;;
      ssh) ssh_menu;;
      advanced) storage_network_advanced_menu;;
    esac
  done
}

health_advanced_menu(){
  while :; do
    c=$(ui_menu 'Monitoring and recovery: Advanced tools' 'Detailed reports, diagnostics and recovery utilities.' \
      inventory 'System inventory' \
      diagnostics 'Comprehensive diagnostics' \
      logs 'Project logs and reports') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      inventory) inventory_menu;;
      diagnostics) diagnostics_full_menu;;
      logs) project_settings_menu;;
    esac
  done
}

monitoring_recovery_menu(){
  while :; do
    c=$(ui_menu 'Monitoring and recovery' 'Monitor health, tune performance and recover from failures.' \
      monitor 'Monitoring dashboard' \
      performance 'Performance tuning' \
      recovery 'Recovery tools' \
      advanced 'Advanced tools') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      monitor) monitoring_center;;
      performance) performance_menu;;
      recovery) recovery_center;;
      advanced) health_advanced_menu;;
    esac
  done
}

# Compatibility wrappers retained for modules and older integrations.
software_packages_menu(){ software_development_menu; }
system_services_menu(){ system_admin_menu; }
system_configuration_menu(){ system_admin_menu; }
user_environment_menu(){ user_interface_menu; }
development_automation_menu(){ software_development_menu; }
development_environment_menu(){ software_development_menu; }
storage_backup_menu(){ storage_network_menu; }
network_security_menu(){ storage_network_menu; }
maintenance_menu(){ monitoring_recovery_menu; }

classic_main_menu(){
  while :; do
    c=$(ui_menu "$PROGRAM $VERSION" "Detected: $DISTRO_ID | $PKG_MGR | $INIT_SYSTEM | $ARCH\nActive AOK rootfs: $(active_rootfs)" \
      workspace 'Workspace dashboard' \
      setup 'Setup and profiles' \
      aok 'iSH-AOK and RootFS' \
      software 'Software and development' \
      system 'System administration' \
      user 'User environment' \
      storage 'Storage, network and backups' \
      health 'Monitoring and recovery' \
      exit 'Exit') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      workspace) workspace_dashboard_v73;;
      setup) setup_profiles_menu;;
      aok) aok_menu;;
      software) software_development_menu;;
      system) system_admin_menu;;
      user) user_interface_menu;;
      storage) storage_network_menu;;
      health) monitoring_recovery_menu;;
      exit) return;;
    esac
  done
}

main(){
  settings_load
  detect_system
  select_ui
  scan_system
  command_registry_build
  activity_add session "Started $PROGRAM $VERSION"
  session_save last_rootfs "$(active_rootfs)"
  log "Started $PROGRAM $VERSION distro=$DISTRO_ID pkg=$PKG_MGR init=$INIT_SYSTEM"
  case ${1:-} in
    --scan) cat "$REPORT_DIR/inventory.txt";;
    --aok-report) AOK_REPORT_QUIET=yes; export AOK_REPORT_QUIET; aok_environment_report; cat "$REPORT_DIR"/aok-environment-*.txt 2>/dev/null | tail -n 500;;
    --workspace-report|--main-menu-report) workspace_report_v90;;
    --architecture-report) v91_architecture_report;;
    --generate-developer-docs) v91_generate_developer_docs;;
    --validate-menus) v91_menu_validate;;
    --menu-audit-report) v952_menu_audit; cat "$V952_MENU_AUDIT_REPORT";;
    --duplicate-menu-report) v960_duplicate_menu_audit; cat "$V960_DUPLICATE_REPORT";;
    --route-audit-report) v962_route_audit; cat "$V962_ROUTE_REPORT";;
    --navigation-registry-report) v970_navigation_audit; cat "$V970_ROUTE_REPORT";;
    --navigation-history-report) v980_navigation_history_report; cat "$V980_REPORT";;
    --navigation-search-report) v990_navigation_search_report; cat "$V990_REPORT";;
    --task-center-report) v1000_task_center_report; cat "$V1000_REPORT";;
    --clear-navigation-history) v980_history_clear;;
    --repair-navigation-state) v970_repair_favorites; cat "$V970_REPAIR_REPORT";;
    --navigation-report) v960_navigation_report;;
    --platform-report) platform_v80_report;;
    --operations-report) v83_operations_report;;
    --distribution-report) root=$(active_rootfs 2>/dev/null || echo /); [ -d "$root" ] || root=/; out=$(v84_distribution_report "$root"); cat "$out";;
    --service-report) root=$(active_rootfs 2>/dev/null || echo /); [ -d "$root" ] || root=/; out=$(service_v85_report "$root"); cat "$out";;
    --build-profile-report) v87_build_profile_report;;
    --build-plan-report) v88_build_plan_report;;
    --build-profiles-report) v89_build_profiles_report;;
    --rootfs-locations-report) v92_locations_report;;
    --tool-audit-report) v942_tools_report;;
    --build-paths-report) v93_build_paths_report_cli;;
    --build-matrix-report) v94_matrix_report_cli;;
    --builder-capabilities-report) v94_capability_report;;
    --v11-capability-report) v11_capability_report "${2:-${DISTRO_ID:-unknown}}";;
    --software-catalog-report) v11_catalog_report;;
    --software-catalog-audit) v11_catalog_audit;;
    --sdk-self-test) v112_sdk_self_test;;
    --diagnostics-audit) v112_bug_audit; _audit_rc=$?; cat "$V112_AUDIT_REPORT"; return "$_audit_rc";;
    --version) printf '%s %s\n' "$PROGRAM" "$VERSION";;
    --v11-plugin-report) v11_plugin_inventory || true;;
        --repository-report) root=$(active_rootfs 2>/dev/null || echo /); [ -d "$root" ] || root=/; out=$(repo_v86_report "$root"); cat "$out";;
    --reliability-report) printf '%s %s — Architecture and Reliability\n' "$PROGRAM" "$VERSION"; printf 'Package manager: %s\n' "$(pkg_api_manager 2>/dev/null || echo unavailable)"; printf 'Cache directory: %s\n' "$V82_CACHE_DIR"; printf 'Developer docs: %s\n' "$V82_DOC_DIR";;
    --workflow-report) workflow_report;;
    --module-report) sdk_module_report;;
    --validate-modules) sdk_discover_modules; rc=0; while IFS="$(printf '\t')" read -r id title category version status origin manifest rest; do sdk_validate_manifest "$manifest" || { printf 'Invalid: %s\n' "$manifest" >&2; rc=1; }; done <"$V75_MODULE_INDEX"; exit "$rc";;
    --workflow) shift; workflow_run_named "${1:-}";;
    --run-action)
      shift
      _cli_action=${1:-}
      command -v command_registry_build >/dev/null 2>&1 && command_registry_build
      if [ -z "$_cli_action" ] || ! command_exists "$_cli_action"; then
        printf 'Unknown action: %s\nRun --registry-report for available actions.\n' "$_cli_action" >&2
        return 2
      fi
      command_run "$_cli_action";;
    --registry-report) REGISTRY_REPORT_QUIET=yes; export REGISTRY_REPORT_QUIET; registry_report;;
    --plugin-report) plugin_list_catalog; printf '\nInstalled:\n'; for f in "$PLUGIN_MANIFEST_DIR"/*.manifest; do [ -f "$f" ] && cat "$f"; done; true;;
    --verbose) VERBOSE=yes; export VERBOSE; shift; main_menu;;
    --debug) VERBOSE=yes; DEBUG=yes; export VERBOSE DEBUG; shift; main_menu;;
    --dry-run) DRY_RUN=yes; export DRY_RUN; shift; main_menu;;
    --help)
      cat <<'EOF_HELP'
Usage: ish-aok-config [OPTION]

Core:
  --help                         Show this help
  --version                      Show the installed version
  --verbose | --debug | --dry-run

Audits and reports:
  --main-menu-report             Main menu/workspace report
  --architecture-report         Architecture report
  --validate-menus              Validate declarative menus
  --menu-audit-report           Full menu audit
  --duplicate-menu-report       Duplicate-menu audit
  --route-audit-report          Route integrity audit
  --software-catalog-report     Software catalog report
  --software-catalog-audit      Validate software catalog handlers
  --sdk-self-test               Run the Plugin/Distribution SDK self-test
  --diagnostics-audit           Run the integrated diagnostics audit
  --navigation-registry-report  Navigation registry report
  --navigation-history-report   Navigation history report
  --navigation-search-report    Navigation search report
  --task-center-report          Task center report
  --platform-report             Platform report
  --operations-report           Operations report
  --distribution-report         Active RootFS distribution report
  --service-report              Active RootFS service report
  --repository-report           Active RootFS repository report
  --build-profile-report        Current build profile report
  --build-plan-report           Current build plan report
  --build-profiles-report       Available build profiles report
  --rootfs-locations-report     RootFS locations report
  --tool-audit-report           Builder tool audit
  --build-paths-report          Builder paths report
  --build-matrix-report         Build matrix report
  --builder-capabilities-report Builder capabilities report
  --v11-capability-report [OS]  v11 capability matrix for a distribution
  --v11-plugin-report           v11 plugin inventory
  --reliability-report          Reliability report
  --workflow-report             Workflow report
  --module-report               Module report
  --registry-report             Command registry report
  --plugin-report               Legacy plugin catalog report
  --scan                        System inventory
  --aok-report                  iSH-AOK environment report

Actions:
  --generate-developer-docs
  --validate-modules
  --workflow ID
  --run-action ID
  --clear-navigation-history
  --repair-navigation-state
  --navigation-report
  --automation TASK [ROOTFS]
EOF_HELP
      ;;
    '') main_menu;;
    -*) printf 'Unknown option: %s\nRun --help for supported options.\n' "$1" >&2; return 2;;
    *) printf 'Unexpected argument: %s\nRun --help for supported options.\n' "$1" >&2; return 2;;
  esac
}
