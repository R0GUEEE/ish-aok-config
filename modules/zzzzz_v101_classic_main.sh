#!/bin/sh
# v10.1 conventional main menu. Workspace UI removed; compatibility aliases remain.

v101_about(){
  root=$(active_rootfs 2>/dev/null || printf '/')
  ui_text 'About iSH-AOK Config' "iSH-AOK Config $VERSION

Main interface: conventional task menu
Active RootFS: $root
Distribution: ${DISTRO_ID:-unknown}
Architecture: ${ARCH:-unknown}
Package manager: ${PKG_MGR:-unknown}
Init system: ${INIT_SYSTEM:-unknown}

Project: https://github.com/emkey1/ish-AOK"
}

v101_status_line(){
  printf 'RootFS: %s\nProfile: %s\nSystem: %s | %s | %s' \
    "$(active_rootfs 2>/dev/null || printf none)" \
    "$(v90_active_profile_name 2>/dev/null || printf none)" \
    "${DISTRO_ID:-unknown}" "${ARCH:-unknown}" "${INIT_SYSTEM:-unknown}"
}

# Override menu metadata without relying on the removed workspace menu.
v91_menu_title(){
  case $1 in
    main) printf '%s %s' "$PROGRAM" "$VERSION";;
    rootfs) printf 'RootFS';;
    build) printf 'Build RootFS';;
    management) printf 'System Tools';;
    reports) printf 'Reports';;
    settings) printf 'Settings';;
    *) printf '%s' "$1";;
  esac
}

v91_menu_text(){
  case $1 in
    main) v101_status_line;;
    rootfs) printf 'Active: %s' "$(active_rootfs 2>/dev/null || printf none)";;
    build) printf 'Profile: %s\nStatus: %s' "$(v90_active_profile_name 2>/dev/null || printf none)" "$(v90_build_status 2>/dev/null || printf idle)";;
    reports) printf 'RootFS, build and system reports.';;
    settings) printf 'Application defaults, plugins and diagnostics.';;
    *) printf 'Select an action.';;
  esac
}

main_menu(){ v91_menu_run main; }
workspace_dashboard_v90(){ main_menu; }
workspace_dashboard_v91(){ main_menu; }
workspace_dashboard_v73(){ main_menu; }
workspace_report_v90(){ printf '%s %s — Main Menu\n' "$PROGRAM" "$VERSION"; v101_status_line; }
workspace_report_v91(){ workspace_report_v90; }

# The removed Task Center is retained only as a compatibility redirect.
v1000_task_center_menu(){ main_menu; }

# Build a command registry without removed Workspace-only actions.
command_registry_build(){
  command_registry_build_base
  tmp=${V73_ACTIONS_FILE}.v101.$$
  awk -F '\t' '$1!="dashboard" && $1!="workspace_context" && $1!="classic_navigation" && $1!="task_center" && $1!="navigation_history" && $1!="navigation_diagnostics"' "$V73_ACTIONS_FILE" >"$tmp"
  mv "$tmp" "$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' main_menu 'Open main menu' Navigation main_menu 'Open the conventional application menu' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_search 'Search all tools' Navigation v990_navigation_search_menu 'Global menu and command search' >>"$V73_ACTIONS_FILE"
}

# v10.1 route audit starts at main.menu and treats only main as Exit owner.
v962_reachable_menus(){
  seen=' main '; queue=main
  while [ -n "$queue" ]; do
    current=${queue%% *}; case $queue in *' '*) queue=${queue#* };; *) queue=;; esac
    children=$(v962_menu_edges | awk -F '|' -v p="$current" '$1==p{print $2}')
    for child in $children; do case $seen in *" $child "*) :;; *) seen="$seen$child "; queue="${queue:+$queue }$child";; esac; done
  done
  for item in $seen; do printf '%s\n' "$item"; done
}

v962_route_manifest(){
  cat <<'ROUTES'
workspace_dashboard_v90|main
workspace_dashboard_v91|main
rootfs_explorer_menu|rootfs
unified_build_menu|build
v90_rootfs_actions_menu|rootfs
v90_build_workflow_menu|build
v90_administration_menu|management
v90_reports_menu|reports
v90_settings_menu|settings
ROUTES
}

v101_route_audit(){
  rc=0
  mkdir -p "$(dirname "$V962_ROUTE_REPORT")" 2>/dev/null || true
  reachable=${TMPDIR:-/tmp}/v101-reachable.$$
  v962_reachable_menus | sort -u >"$reachable"
  {
    printf '%s %s — Menu Routing Audit\n\n' "$PROGRAM" "$VERSION"
    if v91_menu_validate; then printf 'Handlers: PASS\n'; else printf 'Handlers: FAIL\n'; rc=1; fi
    for f in "$V91_MENU_DIR"/*.menu; do
      [ -f "$f" ] || continue; m=${f##*/}; m=${m%.menu}
      grep -qx "$m" "$reachable" || { printf 'Orphan menu: %s\n' "$m"; rc=1; }
      if [ "$m" = main ]; then grep -q '^exit|[^|]*|@return|' "$f" || rc=1; else grep -q '^back|[^|]*|@return|' "$f" || rc=1; fi
    done
    command_registry_build
    while IFS="$(printf '\t')" read -r id title category handler description; do command -v "$handler" >/dev/null 2>&1 || { printf 'Missing command handler: %s -> %s\n' "$id" "$handler"; rc=1; }; done <"$V73_ACTIONS_FILE"
    printf 'Result: %s\n' "$([ "$rc" -eq 0 ] && printf PASS || printf FAIL)"
  } >"$V962_ROUTE_REPORT"
  rm -f "$reachable"
  return "$rc"
}
v962_route_audit(){ v101_route_audit; }
