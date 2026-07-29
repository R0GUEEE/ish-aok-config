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
  command_register rootfs_builder 'Build a Mini RootFS' System v1160_rootfs_menu 'Distribution, release, architecture, init, packages, users and compressed output'
  command_register packages 'Open Package Studio' Software rootfs_package_native 'Native package-manager interface for the active RootFS'
  command_register shell 'Configure shells and prompts' Environment shell_center_v6 'Shell installation, configuration and prompts'
  command_register editor 'Configure editors' Environment editor_center_v6 'Editor installation and configuration'
  command_register terminal 'Configure terminal tools' Environment terminal_center_v6 'Terminal, tmux, Screen and Starship'
  command_register files 'Configure file managers' Environment file_manager_center_v6 'nnn, lf, Ranger, Yazi, Micro and Tere'
  command_register mounts 'Manage mounts' System mount_manager_menu 'Bind, rbind, proc, sysfs, devpts and rootfs profiles'
  command_register network 'Open network center' System network_center 'Interfaces, DNS, routes, proxies and tunnels'
  command_register services 'Open service center' System service_center_v6 'SysVinit, OpenRC and compatible service management'
  command_register performance 'Open performance tuning' System performance_menu 'Low-memory profiles, audits and benchmarks'
  command_register recovery 'Open recovery tools' Recovery recovery_center 'Package, configuration and system recovery'
  command_register workflows 'Open Workflow Engine' Automation workflow_engine_menu 'Reusable pipelines, dependencies, rollback, logs and artifacts'
  command_register settings 'Open project settings' Workspace project_settings_menu 'Application behavior, logging and progress settings'
  command_register reliability 'Open Architecture and Reliability' System v82_reliability_menu 'Unified APIs, portability audits, caches, tests and developer documentation'
  command_register operations 'Open Operations Hardening' System v83_operations_menu 'Transactions, RootFS locks, integrity baselines and rollback journals'
  command_register distribution 'Open Distribution Integration' System v84_distribution_integration_menu 'Distribution, package manager, init and iSH-AOK compatibility profiles'
  command_register service_orchestration 'Open Service and Boot Orchestration' System v85_service_orchestration_menu 'Unified SysVinit, OpenRC, runit and systemd-compatible service operations'
  command_register repository_policy 'Open Repository and Package Policy' Software v86_repository_policy_menu 'Repository audits, package holds, signature policy and configuration snapshots'
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
