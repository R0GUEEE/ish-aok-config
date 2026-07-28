#!/bin/sh

workspace_recent_text(){
  if [ -s "$V73_RECENT_ACTIONS_FILE" ]; then tail -n 6 "$V73_RECENT_ACTIONS_FILE" | awk -F '\t' '{print "• "$1" — "$3}'; else printf '%s\n' '• No recently run actions'; fi
}
workspace_notification_text(){
  if [ -s "$V73_NOTIFICATION_FILE" ]; then tail -n 5 "$V73_NOTIFICATION_FILE" | awk -F '\t' '{printf "• [%s] %s\n",$3,$4}'; else printf '%s\n' '• No notifications'; fi
}
workspace_favorites_text(){
  if [ -s "$V73_FAVORITES_FILE" ]; then while IFS= read -r id; do [ -n "$id" ] && printf '• %s\n' "$(command_field "$id" 2)"; done <"$V73_FAVORITES_FILE"; else printf '%s\n' '• No favorite actions'; fi
}
workspace_rootfs_summary(){
  r=$(active_rootfs); [ -n "$r" ] || r='not selected'
  printf 'Path: %s\n' "$r"
  [ -d "$r" ] || return 0
  rootfs_registry_refresh "$r" >/dev/null 2>&1 || true
  printf 'Distribution: %s\nArchitecture: %s\nInit: %s\nPackage manager: %s\n' \
    "$(rootfs_meta_get "$r" distro)" "$(rootfs_meta_get "$r" arch)" "$(rootfs_meta_get "$r" init)" "$(rootfs_meta_get "$r" package_manager)"
}
workspace_host_status(){
  dfv=$(df -h "$STATE_DIR" 2>/dev/null | awk 'NR==2{print $4" free ("$5" used)"}')
  mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2} END{if(t) printf "%.0f MiB available / %.0f MiB",a/1024,t/1024}' /proc/meminfo 2>/dev/null)
  [ -n "$dfv" ] || dfv='unavailable'; [ -n "$mem" ] || mem='unavailable'
  ui_status_line 'Distribution' "$DISTRO_ID" ok
  ui_status_line 'Architecture' "$ARCH" ok
  ui_status_line 'Init system' "$INIT_SYSTEM" info
  ui_status_line 'Memory' "$mem" info
  ui_status_line 'State storage' "$dfv" info
}
workspace_dashboard_text(){
  mode=$(ui_mode_get)
  if [ "$mode" = compact ]; then
    printf '%s\n' "$(ui_breadcrumb)iSH-AOK Workspace" '' 'Active RootFS' "$(workspace_rootfs_summary)" '' \
      "Favorites" "$(workspace_favorites_text)" '' "Notifications ($(notification_unread_count) unread)" "$(workspace_notification_text)"
  else
    printf '%s\n' "$(ui_breadcrumb)iSH-AOK Workspace" '' 'Active RootFS' "$(workspace_rootfs_summary)" '' \
      'Host status' "$(workspace_host_status)" '' "Favorites" "$(workspace_favorites_text)" '' \
      'Recent actions' "$(workspace_recent_text)" '' "Notifications ($(notification_unread_count) unread)" "$(workspace_notification_text)"
  fi
}

workspace_favorites_menu(){
  while :; do
    set --
    while IFS= read -r id; do [ -n "$id" ] || continue; title=$(command_field "$id" 2); [ -n "$title" ] && set -- "$@" "$id" "$title"; done <"$V73_FAVORITES_FILE"
    [ "$#" -gt 0 ] || { ui_msg Favorites 'No favorite actions. Use Manage favorites to add some.'; return; }
    id=$(ui_menu Favorites 'Choose a favorite action.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    command_run "$id"
  done
}
workspace_manage_favorites(){
  case $UI in
    dialog|whiptail)
      set --
      while IFS='\t' read -r id title category handler description; do favorite_has "$id" && state=on || state=off; set -- "$@" "$id" "$title [$category]" "$state"; done <"$V73_ACTIONS_FILE"
      selected=$(ui_checklist 'Manage favorites' 'Checked actions appear in Favorites.' "$@") || return
      : >"$V73_FAVORITES_FILE"; printf '%s\n' "$selected" | while IFS= read -r id; do [ -n "$id" ] && printf '%s\n' "$id"; done >>"$V73_FAVORITES_FILE";;
    *) id=$(ui_input Favorites 'Action ID to toggle') || return; command_exists "$id" || { ui_msg Favorites "Unknown action: $id"; return; }; favorite_toggle "$id";;
  esac
  activity_add workspace 'Updated favorite actions'
}
workspace_command_palette(){
  q=$(ui_input 'Command palette' 'Search actions by name, category, description, or ID' "$(session_get last_search)") || return
  session_save last_search "$q"; ids=$(command_search_ids "$q")
  [ -n "$ids" ] || { ui_msg 'Command palette' 'No matching actions.'; return; }
  set --; for id in $ids; do set -- "$@" "$id" "$(command_field "$id" 2) [$(command_field "$id" 3)]"; done
  id=$(ui_menu 'Command palette' "Matches for: $q" "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; command_run "$id"
}
workspace_recent_menu(){
  while :; do
    [ -s "$V73_RECENT_ACTIONS_FILE" ] || { ui_msg Activity 'No recently run actions.'; return; }
    set --
    while IFS='\t' read -r ts id title; do command_exists "$id" && set -- "$@" "$id" "$title — $ts"; done <<EOF_RECENT
$(tail -n 20 "$V73_RECENT_ACTIONS_FILE" | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}')
EOF_RECENT
    id=$(ui_menu 'Recent actions' 'Run a recently used action.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    command_run "$id"
  done
}
workspace_notifications_menu(){
  while :; do
    c=$(ui_menu 'Notification center' "Unread: $(notification_unread_count)" view 'View notifications' read 'Mark all as read' clear 'Clear notifications') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in view) ui_text Notifications "$(tail -n 150 "$V73_NOTIFICATION_FILE" | awk -F '\t' '{printf "%s  [%s]  %s  (%s)\n",$2,$3,$4,$5}')";; read) notification_mark_all_read;; clear) ui_yesno Notifications 'Clear all notifications?' && notification_clear;; esac
  done
}
workspace_session_menu(){
  last=$(session_get last_action); root=$(session_get last_rootfs); mode=$(session_get ui_mode)
  text="Last action: ${last:-none}\nLast RootFS: ${root:-none}\nInterface mode: ${mode:-$(ui_mode_get)}"
  c=$(ui_menu 'Session restore' "$text" action 'Run last action' rootfs 'Restore last RootFS selection' clear 'Clear saved session') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  case $c in
    action) [ -n "$last" ] && command_run "$last" || ui_msg Session 'No previous action saved.';;
    rootfs) [ -n "$root" ] && [ -d "$root" ] && { set_active_rootfs "$root"; activity_add session "Restored RootFS $root"; } || ui_msg Session 'The saved RootFS is unavailable.';;
    clear) session_clear; ui_msg Session 'Saved session cleared.';;
  esac
}
workspace_settings_menu(){
  while :; do
    c=$(ui_menu 'Workspace settings' "Interface mode: $(ui_mode_get)" mode 'Compact or full interface' favorites 'Manage favorites' session 'Session restore settings' project 'Project settings') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in mode) ui_mode_menu;; favorites) workspace_manage_favorites;; session) workspace_session_menu;; project) project_settings_menu;; esac
  done
}
workspace_dashboard_v73(){
  old=${V73_BREADCRUMB:-}; V73_BREADCRUMB='Main > Workspace'; export V73_BREADCRUMB
  while :; do
    if [ "$(ui_mode_get)" = compact ]; then
      c=$(ui_menu "$PROGRAM $VERSION — Workspace" "$(workspace_dashboard_text)" palette 'Search and run action' favorites 'Favorites' recent 'Recent actions' notifications 'Notifications' workflows 'Workflow Engine' rootfs 'RootFS registry' settings 'Workspace settings' main 'Classic main menu' refresh 'Refresh') || break
    else
      c=$(ui_menu "$PROGRAM $VERSION — Workspace" "$(workspace_dashboard_text)" palette 'Search and run action' favorites 'Favorite actions' manage 'Manage favorites' recent 'Recent actions' notifications 'Notification center' workflows 'Workflow Engine' rootfs 'Select or manage RootFS' session 'Restore previous session' settings 'Workspace settings' main 'Classic main menu' refresh 'Refresh dashboard') || break
    fi
    case $c in palette) workspace_command_palette;; favorites) workspace_favorites_menu;; manage) workspace_manage_favorites;; recent) workspace_recent_menu;; notifications) workspace_notifications_menu;; workflows) workflow_engine_menu;; rootfs) rootfs_registry_browser;; session) workspace_session_menu;; settings) workspace_settings_menu;; main) main_menu;; refresh) detect_system; scan_system >/dev/null 2>&1 || true;; esac
  done
  V73_BREADCRUMB=$old; export V73_BREADCRUMB
}
workspace_report_v73(){
  command_registry_build
  printf '%s\n' "$(workspace_dashboard_text)" '' 'Registered actions'
  awk -F '\t' '{printf "%-18s %-14s %s\n",$1,$3,$2}' "$V73_ACTIONS_FILE"
}
