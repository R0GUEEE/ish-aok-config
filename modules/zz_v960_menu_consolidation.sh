#!/bin/sh
# v9.6 canonical menu consolidation.

V960_DUPLICATE_REPORT=${V960_DUPLICATE_REPORT:-$REPORT_DIR/menu-duplicates-v960.txt}

# The former Administration tree duplicated System Tools. Keep the legacy
# function name as a compatibility route to the canonical menu.
v90_administration_menu(){ v91_menu_run management; }

v960_menu_action_map(){
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    menu=$(basename "$file" .menu)
    while IFS='|' read -r id label handler description; do
      case $id in ''|'#'*|back|exit) continue;; esac
      case $handler in @return|'') continue;; esac
      printf '%s\t%s\t%s\t%s\n' "$handler" "$menu" "$id" "$label"
    done <"$file"
  done
}

v960_duplicate_menu_audit(){
  rc=0
  tmp=${TMPDIR:-/tmp}/ish-aok-menu-map.$$
  v960_menu_action_map >"$tmp" || return 1
  {
    printf '%s %s — Canonical Menu Audit\n\n' "$PROGRAM" "$VERSION"
    printf 'Each executable handler should have one canonical declarative location.\n'
    printf 'Favorites and the command palette are intentional dynamic shortcuts.\n\n'
  } >"$V960_DUPLICATE_REPORT"
  handlers=$(cut -f1 "$tmp" | sort | uniq -d)
  if [ -n "$handlers" ]; then
    printf 'Duplicate handlers:\n' >>"$V960_DUPLICATE_REPORT"
    for handler in $handlers; do
      printf '  FAIL %s\n' "$handler" >>"$V960_DUPLICATE_REPORT"
      awk -F '\t' -v h="$handler" '$1==h{printf "    %s/%s — %s\n",$2,$3,$4}' "$tmp" >>"$V960_DUPLICATE_REPORT"
      rc=1
    done
  else
    printf 'Duplicate handlers: PASS — none found\n' >>"$V960_DUPLICATE_REPORT"
  fi
  printf '\nResult: %s\n' "$([ "$rc" -eq 0 ] && printf PASS || printf FAIL)" >>"$V960_DUPLICATE_REPORT"
  rm -f "$tmp"
  return "$rc"
}

v960_duplicate_menu_audit_ui(){
  if v960_duplicate_menu_audit; then
    ui_text 'Canonical menu audit' "$(cat "$V960_DUPLICATE_REPORT")"
  else
    ui_text 'Canonical menu audit — duplicates found' "$(cat "$V960_DUPLICATE_REPORT")"
  fi
}

v960_navigation_report(){
  printf '%s %s — Canonical Navigation\n\n' "$PROGRAM" "$VERSION"
  printf 'Canonical menu files: %s\n' "$(find "$V91_MENU_DIR" -name '*.menu' -type f 2>/dev/null | wc -l | tr -d ' ')"
  printf 'Primary workspace entries: %s\n' "$(grep -cv '^#\|^$' "$V91_MENU_DIR/workspace.menu" 2>/dev/null || echo 0)"
  printf 'Duplicate action handlers: '
  if v960_duplicate_menu_audit >/dev/null 2>&1; then printf 'none\n'; else printf 'detected\n'; fi
  printf 'Intentional shortcuts: Favorites, Command Palette\n'
  printf 'Legacy navigation: Settings > Advanced > Classic Navigation\n'
}
