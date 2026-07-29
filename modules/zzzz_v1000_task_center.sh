#!/bin/sh
# v10.0 context-aware task center and workspace recommendations.

V1000_REPORT=${V1000_REPORT:-$REPORT_DIR/task-center-v1000.txt}

v1000_active_rootfs(){ active_rootfs 2>/dev/null || printf '/\n'; }

v1000_rootfs_ready(){
  root=$1
  [ -d "$root" ] && { [ -x "$root/bin/sh" ] || [ -x "$root/usr/bin/sh" ] || [ -x "$root/bin/bash" ]; }
}

v1000_build_profile_path(){
  if command -v v89_active_profile_path >/dev/null 2>&1; then
    v89_active_profile_path 2>/dev/null || true
  elif [ -n "${V89_ACTIVE_PROFILE:-}" ]; then
    printf '%s\n' "$V89_ACTIVE_PROFILE"
  fi
}

v1000_context_text(){
  root=$(v1000_active_rootfs)
  profile=$(v1000_build_profile_path)
  [ -n "$profile" ] || profile='(none)'
  if v1000_rootfs_ready "$root"; then root_state=ready; else root_state='not selected or incomplete'; fi
  printf 'Active RootFS: %s\nRootFS state: %s\nBuild profile: %s\n' "$root" "$root_state" "$profile"
}

v1000_action_available(){ command_exists "$1" 2>/dev/null; }

v1000_recommended_rows(){
  root=$(v1000_active_rootfs)
  printf '%s|%s|%s\n' navigation_search 'Search all tools' 'Find any tool without traversing menus'
}

v1000_run_recommended(){
  set --
  map=$TMP_DIR/v1000-actions.$$
  : >"$map"
  n=0
  while IFS='|' read -r id label reason; do
    v1000_action_available "$id" || continue
    n=$((n+1))
    printf '%s\t%s\n' "$n" "$id" >>"$map"
    set -- "$@" "$n" "$label — $reason"
  done <<EOF_ROWS
$(v1000_recommended_rows)
EOF_ROWS
  [ "$#" -gt 0 ] || { rm -f "$map"; ui_msg 'Task Center' 'No recommended actions are currently available.'; return 0; }
  choice=$(ui_menu 'Recommended Actions' "$(v1000_context_text)" "$@") || { rc=$?; rm -f "$map"; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc"; }
  id=$(awk -F '\t' -v n="$choice" '$1==n{print $2;exit}' "$map")
  rm -f "$map"
  [ -n "$id" ] && command_run "$id"
}

v1000_task_center_report(){
  command_registry_build
  {
    printf '%s %s — Task Center\n\n' "$PROGRAM" "$VERSION"
    v1000_context_text
    printf '\nRecommended actions:\n'
    while IFS='|' read -r id label reason; do
      if v1000_action_available "$id"; then status=available; else status=missing; fi
      printf '  %-20s %-9s %s — %s\n' "$id" "$status" "$label" "$reason"
    done <<EOF_ROWS
$(v1000_recommended_rows)
EOF_ROWS
  } >"$V1000_REPORT"
  ! grep -q ' missing ' "$V1000_REPORT"
}

v1000_task_center_report_ui(){ v1000_task_center_report || true; ui_text 'Task Center Report' "$(cat "$V1000_REPORT")"; }

v1000_task_center_menu(){
  while :; do
    c=$(ui_menu 'Task Center' "$(v1000_context_text)" recommended 'Recommended actions' favorites 'Favorites' recent 'Recent actions' search 'Search all tools' report 'Task Center report' back 'Back') || { rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc"; }
    case $c in
      recommended) v1000_run_recommended;;
      favorites) workspace_favorites_menu;;
      recent) workspace_recent_menu;;
      search) v990_navigation_search_menu;;
      report) v1000_task_center_report_ui;;
      back) return 0;;
    esac
  done
}

# Final registry extension after v9.9.
command_registry_build(){
  command_registry_build_base
  printf '%s\t%s\t%s\t%s\t%s\n' architecture 'Developer architecture' Development v91_developer_center 'Modular menus, docs and tests' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' architecture_report 'Architecture report' Reports v91_architecture_report 'v9.1 modular-core status' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_diagnostics 'Open navigation diagnostics' Workspace v970_navigation_diagnostics_menu 'Canonical routes, audits and saved-state repair' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_history 'Open navigation history' Workspace v980_history_menu 'Breadcrumbs and recently visited canonical menus' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_search 'Search all menu tools' Workspace v990_navigation_search_menu 'Global menu search and most-used actions' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' task_center 'Open Task Center' Workspace v1000_task_center_menu 'Context-aware RootFS, build and navigation actions' >>"$V73_ACTIONS_FILE"
}
