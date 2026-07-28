#!/bin/sh
# v9.8 navigation breadcrumbs, menu history and stale-history repair.

V980_NAV_DIR=${V980_NAV_DIR:-$STATE_DIR/navigation-v980}
V980_HISTORY_FILE=${V980_HISTORY_FILE:-$V980_NAV_DIR/history}
V980_STACK_FILE=${V980_STACK_FILE:-$TMP_DIR/navigation-stack}
V980_REPORT=${V980_REPORT:-$REPORT_DIR/navigation-history-v980.txt}
V980_HISTORY_LIMIT=${V980_HISTORY_LIMIT:-30}
mkdir -p "$V980_NAV_DIR" 2>/dev/null || true
[ -e "$V980_HISTORY_FILE" ] || : >"$V980_HISTORY_FILE"
[ -e "$V980_STACK_FILE" ] || : >"$V980_STACK_FILE"

v980_menu_exists(){ [ -r "$(v91_menu_file "$1")" ]; }

v980_navigation_enter(){
  menu=$1
  last=$(tail -n 1 "$V980_STACK_FILE" 2>/dev/null || true)
  [ "$last" = "$menu" ] || printf '%s\n' "$menu" >>"$V980_STACK_FILE"
  v980_history_record "$menu"
}

v980_navigation_leave(){
  menu=$1
  [ -r "$V980_STACK_FILE" ] || return 0
  tmp=$V980_STACK_FILE.$$
  awk 'NR>1{print prev}{prev=$0}' "$V980_STACK_FILE" >"$tmp"
  mv "$tmp" "$V980_STACK_FILE"
}

v980_navigation_breadcrumb(){
  out=
  [ -r "$V980_STACK_FILE" ] || return 0
  while IFS= read -r menu; do
    [ -n "$menu" ] || continue
    title=$(v91_menu_title "$menu")
    [ -n "$out" ] && out="$out > $title" || out=$title
  done <"$V980_STACK_FILE"
  printf '%s' "$out"
}

v980_navigation_title(){
  menu=$1 fallback=$2
  crumb=$(v980_navigation_breadcrumb)
  [ -n "$crumb" ] && printf '%s' "$crumb" || printf '%s' "$fallback"
}

v980_history_record(){
  menu=$1
  v980_menu_exists "$menu" || return 0
  tmp=$V980_HISTORY_FILE.$$
  { printf '%s|%s\n' "$(date +%s 2>/dev/null || echo 0)" "$menu"; awk -F '|' -v m="$menu" '$2!=m' "$V980_HISTORY_FILE" 2>/dev/null; } | head -n "$V980_HISTORY_LIMIT" >"$tmp"
  mv "$tmp" "$V980_HISTORY_FILE"
}

v980_history_repair(){
  tmp=$V980_HISTORY_FILE.$$
  : >"$tmp"
  seen=' '
  while IFS='|' read -r stamp menu; do
    [ -n "$menu" ] || continue
    v980_menu_exists "$menu" || continue
    case " $seen " in *" $menu "*) continue;; esac
    seen="$seen$menu "
    printf '%s|%s\n' "$stamp" "$menu" >>"$tmp"
  done <"$V980_HISTORY_FILE"
  head -n "$V980_HISTORY_LIMIT" "$tmp" >"$tmp.limit"
  mv "$tmp.limit" "$V980_HISTORY_FILE"
  rm -f "$tmp"
}

v980_history_clear(){ : >"$V980_HISTORY_FILE"; }

v980_history_menu(){
  while :; do
    v980_history_repair
    set --
    while IFS='|' read -r stamp menu; do
      [ -n "$menu" ] || continue
      set -- "$@" "$menu" "$(v91_menu_title "$menu")"
    done <"$V980_HISTORY_FILE"
    [ "$#" -gt 0 ] || { ui_msg 'Navigation History' 'No menu history has been recorded yet.'; return 0; }
    choice=$(ui_menu 'Navigation History' 'Open a recently visited canonical menu.' "$@" clear 'Clear history' back 'Back') || { rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc"; }
    case $choice in
      clear) ui_yesno 'Clear History' 'Remove all saved menu history?' && v980_history_clear;;
      *) v980_menu_exists "$choice" && v91_menu_run "$choice" || ui_msg Navigation "Menu is unavailable: $choice";;
    esac
  done
}

v980_navigation_history_report(){
  v980_history_repair
  {
    printf '%s %s — Navigation History\n\n' "$PROGRAM" "$VERSION"
    printf 'Breadcrumb stack:\n  %s\n\n' "$(v980_navigation_breadcrumb)"
    printf 'Recent canonical menus:\n'
    if [ -s "$V980_HISTORY_FILE" ]; then
      while IFS='|' read -r stamp menu; do printf '  %-20s %s\n' "$menu" "$(v91_menu_title "$menu")"; done <"$V980_HISTORY_FILE"
    else
      printf '  (none)\n'
    fi
    printf '\nHistory file: %s\n' "$V980_HISTORY_FILE"
  } >"$V980_REPORT"
}

v980_navigation_history_ui(){ v980_navigation_history_report; ui_text 'Navigation History Report' "$(cat "$V980_REPORT")"; }

# Preserve the v9.7 registry and append v9.8 actions.
command_registry_build(){
  command_registry_build_base
  printf '%s\t%s\t%s\t%s\t%s\n' architecture 'Developer architecture' Development v91_developer_center 'Modular menus, docs and tests' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' architecture_report 'Architecture report' Reports v91_architecture_report 'v9.1 modular-core status' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_diagnostics 'Open navigation diagnostics' Workspace v970_navigation_diagnostics_menu 'Canonical routes, audits and saved-state repair' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_history 'Open navigation history' Workspace v980_history_menu 'Breadcrumbs and recently visited canonical menus' >>"$V73_ACTIONS_FILE"
}
