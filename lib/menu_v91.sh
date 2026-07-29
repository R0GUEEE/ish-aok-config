#!/bin/sh
# Declarative menu and feature registration for v9.1.
V91_MENU_DIR=${V91_MENU_DIR:-${ISH_AOK_CONFIG_ROOT:-.}/menus}
V91_FEATURE_DIR=${V91_FEATURE_DIR:-${STATE_DIR:-${HOME:-/root}/.local/state/ish-aok-config}/v91/features}
mkdir -p "$V91_FEATURE_DIR" 2>/dev/null || true

v91_menu_file(){ printf '%s/%s.menu' "$V91_MENU_DIR" "$1"; }
v91_field(){ printf '%s' "$1" | sed 's/[|\t\r\n]/ /g'; }

register_menu(){
  menu=$1 item=$2 label=$3 handler=$4 description=${5:-}
  file=$(v91_menu_file "$menu")
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  safe_item=$(v91_field "$item"); safe_label=$(v91_field "$label")
  safe_handler=$(v91_field "$handler"); safe_description=$(v91_field "$description")
  grep -q "^${safe_item}|" "$file" 2>/dev/null && return 0
  printf '%s|%s|%s|%s\n' "$safe_item" "$safe_label" "$safe_handler" "$safe_description" >>"$file"
}
register_action(){
  id=$1 label=$2 category=$3 handler=$4 description=${5:-}
  command -v command_register >/dev/null 2>&1 && command_register "$id" "$label" "$category" "$handler" "$description" || true
}
register_report(){ register_action "$1" "$2" reports "$3" "${4:-}"; }
register_workflow(){
  id=$1 file=$2
  command -v workflow_register_external >/dev/null 2>&1 && workflow_register_external "$id" "$file" || true
}
register_builder(){ register_action "$1" "$2" build "$3" "${4:-}"; }

v91_menu_title(){
  case $1 in
    workspace) printf 'Unified Workspace';;
    rootfs) printf 'RootFS Explorer';;
    build) printf 'Unified Build Studio';;
    administration|management) printf 'System Tools';;
    projects) printf 'Projects & Automation';;
    rootfs_select) printf 'Select RootFS';;
    rootfs_manage) printf 'Manage RootFS';;
    rootfs_protect) printf 'Snapshots & Repair';;
    rootfs_transfer) printf 'Clone, Compare & Export';;
    build_profile) printf 'Build Profile';;
    build_outputs) printf 'Artifacts & Export';;
    reports_system) printf 'System Reports';;
    settings_advanced) printf 'Advanced Settings';;
    reports) printf 'Reports';;
    settings) printf 'Settings';;
    *) printf '%s' "$1";;
  esac
}
v91_menu_text(){
  case $1 in
    workspace) v90_workspace_summary;;
    rootfs) printf 'Active: %s' "$(v90_active_rootfs)";;
    build) printf 'Profile: %s\nStatus: %s' "$(v90_active_profile_name)" "$(v90_build_status)";;
    administration|management) printf 'Packages, services, users, storage and recovery.';;
    projects) printf 'Projects, workflows, recipes and recent activity.';;
    rootfs_select) printf 'Choose a registered RootFS or browse to any path.';;
    rootfs_manage) printf 'Configure packages, repositories, services and boot.';;
    rootfs_protect) printf 'Snapshots, health checks, compatibility and repair.';;
    rootfs_transfer) printf 'Clone, compare, import and export RootFS instances.';;
    build_profile) printf 'Select a preset, configure paths and validate the profile.';;
    build_outputs) printf 'Manage archives, compression and artifact output.';;
    reports_system) printf 'Distribution, service and repository reports.';;
    settings_advanced) printf 'Command palette, developer tools and legacy navigation.';;
    reports) printf 'Generate and review workspace and RootFS reports.';;
    settings) printf 'Workspace and application settings.';;
    *) printf 'Select an action.';;
  esac
}
v91_menu_run(){
  menu=$1; file=$(v91_menu_file "$menu")
  command -v v980_navigation_enter >/dev/null 2>&1 && v980_navigation_enter "$menu"
  [ -r "$file" ] || { ui_msg Menu "Menu definition not found: $file"; return 1; }
  while :; do
    set --
    while IFS='|' read -r id label handler description; do
      case $id in ''|'#'*) continue;; esac
      [ -n "$description" ] && shown="$label — $description" || shown=$label
      set -- "$@" "$id" "$shown"
    done <"$file"
    _v91_title=$(v91_menu_title "$menu")
    command -v v980_navigation_title >/dev/null 2>&1 && _v91_title=$(v980_navigation_title "$menu" "$_v91_title")
    choice=$(ui_menu "$_v91_title" "$(v91_menu_text "$menu")" "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && { command -v v980_navigation_leave >/dev/null 2>&1 && v980_navigation_leave "$menu"; return 0; }; return "$_menu_rc"; };
    v91_menu_dispatch "$menu" "$choice"
    dispatch_rc=$?
    [ "$dispatch_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && { command -v v980_navigation_leave >/dev/null 2>&1 && v980_navigation_leave "$menu"; return 0; }
    [ "$choice" = exit ] && { command -v v980_navigation_leave >/dev/null 2>&1 && v980_navigation_leave "$menu"; return; }
  done
}
v91_menu_dispatch(){
  menu=$1 wanted=$2; file=$(v91_menu_file "$menu")
  while IFS='|' read -r id label handler description; do
    [ "$id" = "$wanted" ] || continue
    command -v v990_usage_record >/dev/null 2>&1 && v990_usage_record "menu:$menu:$id"
    case $handler in
      @menu:*) v91_menu_run "${handler#@menu:}";;
      @action:*) command_run "${handler#@action:}";;
      @return) return "${UI_MENU_BACK_RC:-90}";;
      *) if command -v "$handler" >/dev/null 2>&1; then "$handler"; else ui_msg "$label" "Handler is unavailable: $handler"; return 1; fi;;
    esac
    return $?
  done <"$file"
  ui_msg Menu "Unknown item: $wanted"
  return 1
}

v91_menu_validate(){
  rc=0
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    while IFS='|' read -r id label handler description; do
      case $id in ''|'#'*) continue;; esac
      [ -n "$label" ] && [ -n "$handler" ] || { printf 'Invalid row in %s: %s\n' "$file" "$id" >&2; rc=1; continue; }
      case $handler in
        @menu:*) [ -r "$(v91_menu_file "${handler#@menu:}")" ] || { printf 'Missing submenu %s from %s\n' "$handler" "$file" >&2; rc=1; };;
        @action:*|@return) :;;
        *) command -v "$handler" >/dev/null 2>&1 || { printf 'Missing handler %s from %s\n' "$handler" "$file" >&2; rc=1; };;
      esac
    done <"$file"
  done
  return "$rc"
}
