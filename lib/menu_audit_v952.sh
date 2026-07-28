#!/bin/sh
V952_MENU_AUDIT_REPORT=${V952_MENU_AUDIT_REPORT:-$REPORT_DIR/menu-audit-v952.txt}

v952_menu_audit(){
  rc=0
  : >"$V952_MENU_AUDIT_REPORT" || return 1
  {
    printf '%s %s — Menu Audit\n\n' "$PROGRAM" "$VERSION"
    printf 'Declarative menus:\n'
  } >>"$V952_MENU_AUDIT_REPORT"
  if v91_menu_validate >>"$V952_MENU_AUDIT_REPORT" 2>&1; then
    printf '  PASS: all declarative handlers and submenus resolve\n' >>"$V952_MENU_AUDIT_REPORT"
  else
    printf '  FAIL: declarative validation errors detected\n' >>"$V952_MENU_AUDIT_REPORT"; rc=1
  fi

  command_registry_build
  printf '\nCommand registry:\n' >>"$V952_MENU_AUDIT_REPORT"
  while IFS="$(printf '\t')" read -r id title category handler description; do
    [ -n "$id" ] || continue
    if command -v "$handler" >/dev/null 2>&1; then
      printf '  PASS %-24s %s\n' "$id" "$handler" >>"$V952_MENU_AUDIT_REPORT"
    else
      printf '  FAIL %-24s missing %s\n' "$id" "$handler" >>"$V952_MENU_AUDIT_REPORT"; rc=1
    fi
  done <"$V73_ACTIONS_FILE"

  printf '\nDuplicate declarative IDs:\n' >>"$V952_MENU_AUDIT_REPORT"
  dup=0
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    ids=$(awk -F '|' '$1!="" && $1 !~ /^#/{print $1}' "$file" | sort | uniq -d)
    if [ -n "$ids" ]; then
      dup=1; rc=1
      printf '  FAIL %s: %s\n' "$(basename "$file")" "$(printf '%s' "$ids" | tr '\n' ' ')" >>"$V952_MENU_AUDIT_REPORT"
    fi
  done
  [ "$dup" -eq 0 ] && printf '  PASS: no duplicate IDs\n' >>"$V952_MENU_AUDIT_REPORT"

  printf '\nUI primitives:\n' >>"$V952_MENU_AUDIT_REPORT"
  for fn in ui_menu ui_checklist ui_radiolist ui_input ui_yesno; do
    if command -v "$fn" >/dev/null 2>&1; then printf '  PASS %s\n' "$fn" >>"$V952_MENU_AUDIT_REPORT"; else printf '  FAIL %s missing\n' "$fn" >>"$V952_MENU_AUDIT_REPORT"; rc=1; fi
  done
  printf '\nResult: %s\n' "$([ "$rc" -eq 0 ] && printf PASS || printf FAIL)" >>"$V952_MENU_AUDIT_REPORT"
  return "$rc"
}

v952_menu_audit_ui(){
  if v952_menu_audit; then ui_text 'Menu audit' "$(cat "$V952_MENU_AUDIT_REPORT")"; else ui_text 'Menu audit — issues found' "$(cat "$V952_MENU_AUDIT_REPORT")"; fi
}
