#!/bin/sh

V73_ACTIONS_FILE=${V73_ACTIONS_FILE:-$STATE_DIR/workspace/actions.tsv}
mkdir -p "$(dirname "$V73_ACTIONS_FILE")" 2>/dev/null || true

command_register(){
  id=$1; title=$2; category=$3; handler=$4; description=${5:-$2}
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$title" "$category" "$handler" "$description" >>"$V73_ACTIONS_FILE.tmp"
}

command_registry_build_base(){
  : >"$V73_ACTIONS_FILE.tmp"
  command_register dashboard 'Open workspace dashboard (Unified)' Workspace workspace_dashboard_v90 'Status, recent activity, favorites and notifications'
  command_register rootfs_registry 'Browse RootFS registry' RootFS rootfs_registry_browser 'Search, select and inspect registered root filesystems'
  command_register health 'Run interactive health dashboard' RootFS rootfs_health_interactive 'RootFS health score, details and repairs'
  command_register chroot 'Open Chroot Studio' RootFS rootfs_chroot_studio 'Validated chroot profiles and mount preparation'
  command_register snapshot 'Browse snapshots' RootFS rootfs_snapshot_browser 'Compare, restore, export and remove snapshots'
  command_register diff 'Compare RootFS instances' RootFS rootfs_diff_viewer 'Packages, users, services, repositories and configuration differences'
  command_register build 'Open Builder Studio' Build aok_builder_studio 'Build recipes, queues and artifacts'
  command_register queue 'Open build queue' Build build_queue_manager_v71 'Manage reproducible queued build plans'
  command_register packages 'Open Package Studio' Software rootfs_package_native 'Native package-manager interface for the active RootFS'
  command_register plugins 'Open plugin marketplace' Software plugin_marketplace_enhanced 'Browse and manage curated plugins'
  command_register shell 'Configure shells and prompts' Environment shell_center_v6 'Shells, frameworks, plugins and prompts'
  command_register editor 'Configure editors' Environment editor_center_v6 'Editor configuration and plugin managers'
  command_register terminal 'Configure terminal tools' Environment terminal_center_v6 'Terminal, tmux, Screen and Starship'
  command_register files 'Configure file managers' Environment file_manager_center_v6 'nnn, lf, Ranger, Yazi, Micro and Tere'
  command_register mounts 'Manage mounts' System mount_manager_menu 'Bind, rbind, proc, sysfs, devpts and rootfs profiles'
  command_register network 'Open network center' System network_center 'Interfaces, DNS, routes, proxies and tunnels'
  command_register services 'Open service center' System service_center_v6 'SysVinit, OpenRC and compatible service management'
  command_register performance 'Open performance tuning' System performance_menu 'Low-memory profiles, audits and benchmarks'
  command_register reports 'Generate RootFS reports' Reports rootfs_report_generate 'Markdown, JSON, HTML and text reports'
  command_register compatibility 'Run compatibility analysis' Reports compatibility_deep_report_v72 'iSH-AOK assumptions, ELF, init and device checks'
  command_register recovery 'Open recovery tools' Recovery recovery_center 'Package, configuration and system recovery'
  command_register workflows 'Open Workflow Engine' Automation workflow_engine_menu 'Reusable pipelines, dependencies, rollback, logs and artifacts'
  command_register settings 'Open project settings' Workspace project_settings_menu 'Application behavior, logging and diagnostics'
  command_register sdk 'Open Module and Plugin SDK' Extensions sdk_center 'Dynamic module discovery, validation, installation and contributor tools'
  command_register platform 'Open v8 RootFS Platform' RootFS platform_v80_menu 'Projects, recipes, multi-RootFS operations, monitoring, plugin repositories and docs'
  command_register projects 'Open RootFS Projects' RootFS rootfs_projects_menu 'Project-oriented RootFS lifecycle management'
  command_register recipes 'Open Build Recipes' Build build_recipes_menu 'Reusable build definitions and execution plans'
  command_register multi_rootfs 'Open Multi-RootFS Workspace' RootFS multi_rootfs_menu 'Compare and operate across registered RootFS instances'
  command_register plugin_repo 'Open Plugin Repository' Extensions plugin_repository_menu 'Search and install extension packages from optional indexes'
  command_register reliability 'Open Architecture and Reliability' System v82_reliability_menu 'Unified APIs, portability audits, caches, tests and developer documentation'
  command_register operations 'Open Operations Hardening' System v83_operations_menu 'Transactions, RootFS locks, integrity baselines and rollback journals'
  command_register distribution 'Open Distribution Integration' System v84_distribution_integration_menu 'Distribution, package manager, init and iSH-AOK compatibility profiles'
  command_register service_orchestration 'Open Service and Boot Orchestration' System v85_service_orchestration_menu 'Unified SysVinit, OpenRC, runit and systemd-compatible service operations'
  command_register repository_policy 'Open Repository and Package Policy' Software v86_repository_policy_menu 'Repository audits, package holds, signature policy and configuration snapshots'
  command_register build_execution 'Open Build Execution and Recovery' Build v88_build_execution_menu 'Preflight, staged execution, resume, diagnostics and safe cleanup'
  command_register build_profiles 'Open Build Profiles and Presets' Build v89_profile_manager_menu 'Reusable presets, cloning, comparison and validation for RootFS builds'
  command_register rootfs_locations 'Manage RootFS Build Locations' Build v92_location_manager_menu 'Select and validate builder destinations, recent paths and standard iSH-AOK roots'
  command_register rootfs_explorer 'Open RootFS Explorer' RootFS rootfs_explorer_menu 'Context-aware RootFS actions in one interface'
  command_register rootfs_anywhere 'Select RootFS from anywhere' RootFS rootfs_select_anywhere 'Enter or browse to any accessible RootFS path'
  command_register chroot_anywhere 'Chroot any RootFS directory' RootFS v951_chroot_any_directory 'Select any RootFS path, prepare mounts and enter it'
  command_register package_rootfs 'Package any RootFS directory' RootFS v951_package_rootfs_directory 'Create a checksummed tarball from an existing RootFS directory'
  command_register unified_build 'Open Unified Build Studio' Build v90_build_workflow_menu 'Preset, configure, validate, plan, execute and recover builds'
  command_register workspace_context 'Change workspace context' Workspace v90_context_menu 'Select active RootFS, project and build profile'
  command_register classic_navigation 'Open Classic Navigation' Workspace classic_main_menu 'Access the preserved v8 menu structure'
  command -v sdk_register_actions >/dev/null 2>&1 && sdk_register_actions
  mv "$V73_ACTIONS_FILE.tmp" "$V73_ACTIONS_FILE"
}

command_field(){ awk -F '\t' -v id="$1" -v n="$2" '$1==id{print $n;exit}' "$V73_ACTIONS_FILE"; }
command_exists(){ awk -F '\t' -v id="$1" '$1==id{f=1} END{exit !f}' "$V73_ACTIONS_FILE"; }

command_run(){
  id=$1
  command_exists "$id" || { ui_msg 'Command palette' "Unknown action: $id"; return 1; }
  handler=$(command_field "$id" 4)
  title=$(command_field "$id" 2)
  command -v "$handler" >/dev/null 2>&1 || { notification_add error "Missing handler for $title: $handler"; ui_msg Error "Handler unavailable: $handler"; return 1; }
  session_save last_action "$id"
  activity_add "action:$id" "$title"
  recent_action_add "$id" "$title"
  event_emit command.started "$id"
  "$handler"
  rc=$?
  event_emit command.finished "$id rc=$rc"
  [ "$rc" -eq 0 ] || notification_add warning "$title exited with status $rc"
  return "$rc"
}

command_search_ids(){
  q=$1
  awk -F '\t' -v q="$q" 'BEGIN{IGNORECASE=1} index($1,q)||index($2,q)||index($3,q)||index($5,q){print $1}' "$V73_ACTIONS_FILE"
}
