#!/bin/sh
# v9.7 canonical route registry, stale-state repair and navigation diagnostics.

V970_ROUTE_FILE=${V970_ROUTE_FILE:-${ISH_AOK_CONFIG_ROOT:-.}/config/routes.conf}
V970_ROUTE_REPORT=${V970_ROUTE_REPORT:-$REPORT_DIR/navigation-v970.txt}
V970_REPAIR_REPORT=${V970_REPAIR_REPORT:-$REPORT_DIR/navigation-repair-v970.txt}

v970_route_rows(){
  [ -r "$V970_ROUTE_FILE" ] || return 1
  while IFS='|' read -r id kind target canonical description; do
    case $id in ''|'#'*) continue;; esac
    printf '%s|%s|%s|%s|%s\n' "$id" "$kind" "$target" "$canonical" "$description"
  done <"$V970_ROUTE_FILE"
}

v970_route_field(){
  key=$1; field=$2
  v970_route_rows | awk -F '|' -v key="$key" -v n="$field" '$1==key{print $n;exit}'
}

v970_route_menu(){ v970_route_field "$1" 3; }
v970_route_canonical_id(){ v970_route_field "$1" 4; }

v970_open_route(){
  route=$1
  menu=$(v970_route_menu "$route")
  [ -n "$menu" ] || { ui_msg Navigation "Unknown route: $route"; return 1; }
  v91_menu_run "$menu"
}

# All compatibility entry points now resolve through one registry.
workspace_dashboard_v90(){ v970_open_route workspace_dashboard_v90; }
workspace_dashboard_v91(){ v970_open_route workspace_dashboard_v91; }
rootfs_explorer_menu(){ v970_open_route rootfs_explorer_menu; }
v90_rootfs_actions_menu(){ v970_open_route v90_rootfs_actions_menu; }
unified_build_menu(){ v970_open_route unified_build_menu; }
v90_build_workflow_menu(){ v970_open_route v90_build_workflow_menu; }
v90_administration_menu(){ v970_open_route v90_administration_menu; }
v90_reports_menu(){ v970_open_route v90_reports_menu; }
v90_settings_menu(){ v970_open_route v90_settings_menu; }

v970_favorite_alias_id(){
  case $1 in
    workspace_dashboard_v90|workspace_dashboard_v91|dashboard) printf '%s\n' dashboard;;
    rootfs_explorer_menu|v90_rootfs_actions_menu|rootfs) printf '%s\n' rootfs_explorer;;
    unified_build_menu|v90_build_workflow_menu|build) printf '%s\n' unified_build;;
    v90_administration_menu|management) printf '%s\n' system_tools;;
    v90_reports_menu) printf '%s\n' reports;;
    v90_settings_menu) printf '%s\n' settings;;
    *) printf '%s\n' "$1";;
  esac
}

v970_repair_favorites(){
  command_registry_build
  tmp=${V73_FAVORITES_FILE}.v970.$$
  changed=0; kept=0; removed=0
  : >"$tmp"
  [ -r "$V73_FAVORITES_FILE" ] || : >"$V73_FAVORITES_FILE"
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    new=$(v970_favorite_alias_id "$old")
    command_exists "$new" || { removed=$((removed+1)); changed=1; continue; }
    grep -Fqx "$new" "$tmp" 2>/dev/null && { changed=1; continue; }
    printf '%s\n' "$new" >>"$tmp"; kept=$((kept+1))
    [ "$new" = "$old" ] || changed=1
  done <"$V73_FAVORITES_FILE"
  mv "$tmp" "$V73_FAVORITES_FILE"
  {
    printf '%s %s — Saved Navigation Repair\n\n' "$PROGRAM" "$VERSION"
    printf 'Favorites retained: %s\nFavorites removed: %s\nChanges applied: %s\n' "$kept" "$removed" "$changed"
  } >"$V970_REPAIR_REPORT"
  return 0
}

v970_navigation_audit(){
  rc=0
  mkdir -p "$(dirname "$V970_ROUTE_REPORT")" 2>/dev/null || true
  command_registry_build
  {
    printf '%s %s — Navigation Registry Audit\n\n' "$PROGRAM" "$VERSION"
    printf 'Route registry: %s\n\n' "$V970_ROUTE_FILE"
    printf 'Registry entries:\n'
  } >"$V970_ROUTE_REPORT"
  seen=' '
  v970_route_rows | while IFS='|' read -r id kind target canonical description; do
    status=PASS
    case " $seen " in *" $id "*) status=FAIL;; esac
    seen="$seen$id "
    [ -r "$(v91_menu_file "$target")" ] || status=FAIL
    [ -n "$canonical" ] || status=FAIL
    printf '  %s %-30s %-7s -> %-20s [%s]\n' "$status" "$id" "$kind" "$target" "$canonical"
  done >>"$V970_ROUTE_REPORT"

  # Re-evaluate failures outside the pipeline so POSIX subshell behavior cannot hide rc.
  ids=$(v970_route_rows | cut -d '|' -f1)
  dups=$(printf '%s\n' "$ids" | sort | uniq -d)
  [ -z "$dups" ] || rc=1
  while IFS='|' read -r id kind target canonical description; do
    [ -r "$(v91_menu_file "$target")" ] || rc=1
  done <<EOF_ROWS
$(v970_route_rows)
EOF_ROWS

  printf '\nSaved favorites:\n' >>"$V970_ROUTE_REPORT"
  stale=0
  if [ -r "$V73_FAVORITES_FILE" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      mapped=$(v970_favorite_alias_id "$id")
      if command_exists "$mapped"; then
        printf '  PASS %-24s -> %s\n' "$id" "$mapped" >>"$V970_ROUTE_REPORT"
      else
        printf '  FAIL %-24s unavailable\n' "$id" >>"$V970_ROUTE_REPORT"; stale=1
      fi
    done <"$V73_FAVORITES_FILE"
  fi
  [ "$stale" -eq 0 ] || rc=1

  printf '\nUnderlying route audit:\n' >>"$V970_ROUTE_REPORT"
  if v962_route_audit; then
    printf '  PASS v9.6.2 complete routing audit\n' >>"$V970_ROUTE_REPORT"
  else
    printf '  FAIL v9.6.2 complete routing audit\n' >>"$V970_ROUTE_REPORT"; rc=1
  fi
  printf '\nResult: %s\n' "$([ "$rc" -eq 0 ] && printf PASS || printf FAIL)" >>"$V970_ROUTE_REPORT"
  return "$rc"
}

v970_navigation_diagnostics_menu(){
  while :; do
    c=$(ui_menu 'Navigation Diagnostics' 'Inspect canonical routes and repair stale saved navigation.' audit 'Run complete navigation audit' repair 'Repair saved Favorites' routes 'View canonical route registry' old 'View v9.6 routing report') || { r=$?; [ "$r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$r"; }
    case $c in
      audit) v970_navigation_audit; ui_text 'Navigation audit' "$(cat "$V970_ROUTE_REPORT")";;
      repair) v970_repair_favorites; ui_text 'Navigation repair' "$(cat "$V970_REPAIR_REPORT")";;
      routes) ui_text 'Canonical routes' "$(v970_route_rows)";;
      old) v962_route_audit; ui_text 'Complete routing audit' "$(cat "$V962_ROUTE_REPORT")";;
    esac
  done
}

v970_navigation_audit_ui(){
  v970_navigation_audit || true
  ui_text 'Navigation registry audit' "$(cat "$V970_ROUTE_REPORT")"
}

# Append v9.7 diagnostics to the command registry after all earlier overrides.
command_registry_build_v970_parent=$(command -v command_registry_build 2>/dev/null || true)
command_registry_build(){
  command_registry_build_base
  printf '%s\t%s\t%s\t%s\t%s\n' architecture 'Developer architecture' Development v91_developer_center 'Modular menus, docs and tests' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' architecture_report 'Architecture report' Reports v91_architecture_report 'v9.1 modular-core status' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_diagnostics 'Open navigation diagnostics' Workspace v970_navigation_diagnostics_menu 'Canonical routes, audits and saved-state repair' >>"$V73_ACTIONS_FILE"
}
