#!/bin/sh
# v9.6.2 canonical route aliases and complete menu-routing audit.

V962_ROUTE_REPORT=${V962_ROUTE_REPORT:-$REPORT_DIR/menu-routing-v962.txt}

# Canonical compatibility routes. Older modules, plugins, favorites and saved
# command IDs may still call these names; all now terminate at the v9.6 menu tree.
workspace_dashboard_v90(){ v91_menu_run workspace; }
workspace_dashboard_v91(){ v91_menu_run workspace; }
rootfs_explorer_menu(){ main_menu; }
unified_build_menu(){ v91_menu_run rootfs; }
v90_rootfs_actions_menu(){ main_menu; }
v90_build_workflow_menu(){ v91_menu_run rootfs; }
v90_administration_menu(){ v91_menu_run management; }
v90_reports_menu(){ v91_menu_run main; }
v90_settings_menu(){ v91_menu_run settings; }

v962_route_manifest(){
  cat <<'ROUTES'
workspace_dashboard_v90|workspace
workspace_dashboard_v91|workspace
v90_administration_menu|management
v90_reports_menu|main
v90_settings_menu|settings
ROUTES
}

v962_menu_edges(){
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    parent=$(basename "$file" .menu)
    while IFS='|' read -r id label handler description; do
      case $id in ''|'#'*) continue;; esac
      case $handler in @menu:*) printf '%s|%s|%s\n' "$parent" "${handler#@menu:}" "$id";; esac
    done <"$file"
  done
}

v962_reachable_menus(){
  seen=' workspace '
  queue=workspace
  while [ -n "$queue" ]; do
    current=${queue%% *}
    case $queue in *' '*) queue=${queue#* };; *) queue=;; esac
    children=$(v962_menu_edges | awk -F '|' -v p="$current" '$1==p{print $2}')
    for child in $children; do
      case $seen in *" $child "*) :;; *) seen="$seen$child "; queue="${queue:+$queue }$child";; esac
    done
  done
  for item in $seen; do printf '%s\n' "$item"; done
}

v962_route_audit(){
  rc=0
  tmp=${TMPDIR:-/tmp}/ish-aok-route-audit.$$
  edges=$tmp.edges
  reachable=$tmp.reachable
  registry=$tmp.registry
  mkdir -p "$(dirname "$V962_ROUTE_REPORT")" 2>/dev/null || true
  v962_menu_edges >"$edges"
  v962_reachable_menus | sort -u >"$reachable"
  command_registry_build
  cp "$V73_ACTIONS_FILE" "$registry"

  {
    printf '%s %s — Complete Menu Routing Audit\n\n' "$PROGRAM" "$VERSION"
    printf 'Declarative route validation:\n'
  } >"$V962_ROUTE_REPORT"

  if v91_menu_validate >>"$V962_ROUTE_REPORT" 2>&1; then
    printf '  PASS all menu handlers and submenu targets resolve\n' >>"$V962_ROUTE_REPORT"
  else
    printf '  FAIL unresolved menu handlers or submenu targets\n' >>"$V962_ROUTE_REPORT"; rc=1
  fi

  printf '\nMenu graph:\n' >>"$V962_ROUTE_REPORT"
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    menu=$(basename "$file" .menu)
    if grep -qx "$menu" "$reachable"; then
      printf '  PASS reachable %-24s\n' "$menu" >>"$V962_ROUTE_REPORT"
    else
      printf '  FAIL orphaned  %-24s\n' "$menu" >>"$V962_ROUTE_REPORT"; rc=1
    fi
  done

  # The declarative graph must be acyclic. A submenu returning to a parent is
  # represented by @return, not by another @menu edge.
  printf '\nGraph cycles:\n' >>"$V962_ROUTE_REPORT"
  cycle=0
  while IFS='|' read -r start child item; do
    [ -n "$start" ] || continue
    frontier=$child; visited=" $start "
    while [ -n "$frontier" ]; do
      node=${frontier%% *}
      case $frontier in *' '*) frontier=${frontier#* };; *) frontier=;; esac
      [ "$node" = "$start" ] && { printf '  FAIL cycle through %s/%s -> %s\n' "$start" "$item" "$child" >>"$V962_ROUTE_REPORT"; cycle=1; break; }
      case $visited in *" $node "*) continue;; esac
      visited="$visited$node "
      next=$(awk -F '|' -v p="$node" '$1==p{print $2}' "$edges")
      for n in $next; do frontier="${frontier:+$frontier }$n"; done
    done
  done <"$edges"
  [ "$cycle" -eq 0 ] && printf '  PASS no submenu cycles\n' >>"$V962_ROUTE_REPORT" || rc=1

  printf '\nBack and exit routes:\n' >>"$V962_ROUTE_REPORT"
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    menu=$(basename "$file" .menu)
    if [ "$menu" = workspace ]; then
      grep -q '^exit|[^|]*|@return|' "$file" && printf '  PASS %-24s explicit Exit\n' "$menu" >>"$V962_ROUTE_REPORT" || { printf '  FAIL %-24s missing Exit route\n' "$menu" >>"$V962_ROUTE_REPORT"; rc=1; }
    else
      grep -q '^back|[^|]*|@return|' "$file" && printf '  PASS %-24s explicit Back\n' "$menu" >>"$V962_ROUTE_REPORT" || { printf '  FAIL %-24s missing Back route\n' "$menu" >>"$V962_ROUTE_REPORT"; rc=1; }
    fi
  done

  printf '\nCompatibility aliases:\n' >>"$V962_ROUTE_REPORT"
  while IFS='|' read -r alias target; do
    if command -v "$alias" >/dev/null 2>&1 && [ -r "$(v91_menu_file "$target")" ]; then
      printf '  PASS %-28s -> %s\n' "$alias" "$target" >>"$V962_ROUTE_REPORT"
    else
      printf '  FAIL %-28s -> %s\n' "$alias" "$target" >>"$V962_ROUTE_REPORT"; rc=1
    fi
  done <<EOF_ROUTES
$(v962_route_manifest)
EOF_ROUTES

  printf '\nCommand registry:\n' >>"$V962_ROUTE_REPORT"
  dup_ids=$(cut -f1 "$registry" | sort | uniq -d)
  if [ -n "$dup_ids" ]; then
    printf '  FAIL duplicate IDs: %s\n' "$(printf '%s' "$dup_ids" | tr '\n' ' ')" >>"$V962_ROUTE_REPORT"; rc=1
  else
    printf '  PASS unique command IDs\n' >>"$V962_ROUTE_REPORT"
  fi
  while IFS="$(printf '\t')" read -r id title category handler description; do
    [ -n "$id" ] || continue
    if command -v "$handler" >/dev/null 2>&1; then
      printf '  PASS %-24s %s\n' "$id" "$handler" >>"$V962_ROUTE_REPORT"
    else
      printf '  FAIL %-24s missing %s\n' "$id" "$handler" >>"$V962_ROUTE_REPORT"; rc=1
    fi
  done <"$registry"

  printf '\nCanonical command routes:\n' >>"$V962_ROUTE_REPORT"
  for spec in 'dashboard:workspace_dashboard_v90' 'classic_navigation:classic_main_menu'; do
    id=${spec%%:*}; expected=${spec#*:}; actual=$(awk -F '\t' -v id="$id" '$1==id{print $4;exit}' "$registry")
    if [ "$actual" = "$expected" ]; then
      printf '  PASS %-24s %s\n' "$id" "$actual" >>"$V962_ROUTE_REPORT"
    else
      printf '  FAIL %-24s expected %s, found %s\n' "$id" "$expected" "${actual:-missing}" >>"$V962_ROUTE_REPORT"; rc=1
    fi
  done

  printf '\nResult: %s\n' "$([ "$rc" -eq 0 ] && printf PASS || printf FAIL)" >>"$V962_ROUTE_REPORT"
  rm -f "$edges" "$reachable" "$registry"
  return "$rc"
}

v962_route_audit_ui(){
  if v962_route_audit; then
    ui_text 'Menu routing audit' "$(cat "$V962_ROUTE_REPORT")"
  else
    ui_text 'Menu routing audit — issues found' "$(cat "$V962_ROUTE_REPORT")"
  fi
}
