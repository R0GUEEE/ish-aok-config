#!/bin/sh
# v10.12.0: menu optimization, integrated diagnostics, and release bug audit.

V112_AUDIT_REPORT=${V112_AUDIT_REPORT:-$REPORT_DIR/system-audit-v112.txt}

v112_pass(){ printf 'PASS  %s\n' "$1" >>"$V112_AUDIT_REPORT"; }
v112_warn(){ printf 'WARN  %s\n' "$1" >>"$V112_AUDIT_REPORT"; }
v112_fail(){ printf 'FAIL  %s\n' "$1" >>"$V112_AUDIT_REPORT"; V112_AUDIT_RC=1; }

v112_check_command(){
  label=$1; fn=$2
  command -v "$fn" >/dev/null 2>&1 && v112_pass "$label ($fn)" || v112_fail "$label: missing handler $fn"
}

v112_shell_syntax_scan(){
  bad=0 count=0
  while IFS= read -r file; do
    count=$((count + 1))
    if ! sh -n "$file" >/dev/null 2>&1; then
      v112_fail "Shell syntax: ${file#$ISH_AOK_CONFIG_ROOT/}"
      bad=$((bad + 1))
    fi
  done <<EOF_FILES
$(find "$ISH_AOK_CONFIG_ROOT" -type f \( -name '*.sh' -o -name 'ish-aok-config' -o -name 'install.sh' -o -name 'uninstall.sh' \) 2>/dev/null | sort)
EOF_FILES
  [ "$bad" -eq 0 ] && v112_pass "Shell syntax: $count files"
}

v112_declarative_menu_scan(){
  if command -v v91_menu_validate >/dev/null 2>&1; then
    if v91_menu_validate >/tmp/ish-aok-v112-menu.$$ 2>&1; then
      v112_pass 'Declarative menu handlers and submenu targets'
    else
      v112_fail 'Declarative menu validation'
      sed 's/^/      /' /tmp/ish-aok-v112-menu.$$ >>"$V112_AUDIT_REPORT"
    fi
    rm -f /tmp/ish-aok-v112-menu.$$
  else
    v112_warn 'Declarative menu validator is unavailable'
  fi
}

v112_menu_file_scan(){
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    menu=${file##*/}; menu=${menu%.menu}
    if [ "$menu" = main ] || [ "$menu" = workspace ]; then
      grep -Eq '^(exit|back)\|[^|]*\|@return\|' "$file" && v112_pass "Menu exit route: $menu" || v112_fail "Menu exit route missing: $menu"
    else
      grep -q '^back|[^|]*|@return|' "$file" && v112_pass "Menu Back route: $menu" || v112_fail "Menu Back route missing: $menu"
    fi
    duplicates=$(awk -F '|' '$1!="" && $1 !~ /^#/{print $1}' "$file" | sort | uniq -d)
    [ -z "$duplicates" ] && v112_pass "Unique entries: $menu" || v112_fail "Duplicate entries in $menu: $(printf '%s' "$duplicates" | tr '\n' ' ')"
  done
}

v112_editor_scan(){
  if ed=$(v110_editor_command 2>/dev/null); then
    v112_pass "Editor launcher: $ed"
  else
    v112_warn 'No interactive editor is currently installed; editor menus will offer installation'
  fi
  v112_check_command 'Shared file editor' edit_file
  v112_check_command 'APT sources editor' v108_apt_sources_menu
  v112_check_command 'Repository source manager' v108_repository_sources_menu
}

v112_package_menu_scan(){
  for spec in \
    'Package checklist engine:v107_manage_group' \
    'Package install batch:v105_install_keys' \
    'Optional package managers:v108_package_managers_menu' \
    'Keyring manager:v109_repository_keyrings_menu' \
    'System package center:v108_system_packages_menu'; do
    v112_check_command "${spec%%:*}" "${spec#*:}"
  done
}

v112_rootfs_scan(){
  for spec in \
    'RootFS keyring preflight:v111_builder_keyring_preflight' \
    'Foreign keyring bootstrap:v111_bootstrap_deb_keyring' \
    'Debootstrap runner:v110_debootstrap_run' \
    'Builder keyring menu:v110_rootfs_keyrings_menu'; do
    v112_check_command "${spec%%:*}" "${spec#*:}"
  done
  for distro in ubuntu debian devuan kali raspbian; do
    v111_distro_keyring_metadata "$distro" >/dev/null 2>&1 && v112_pass "RootFS keyring mapping: $distro" || v112_fail "RootFS keyring mapping missing: $distro"
  done
}

v112_repository_scan(){
  case ${PKG_MGR:-unknown} in
    apt)
      [ -r /etc/apt/sources.list ] || [ -d /etc/apt/sources.list.d ] && v112_pass 'APT repository configuration path' || v112_warn 'No APT source files detected'
      missing=$(grep -Rhso 'signed-by=[^] ,]*' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sed 's/^signed-by=//' | while IFS= read -r f; do [ -e "$f" ] || printf '%s\n' "$f"; done | sort -u)
      [ -z "$missing" ] && v112_pass 'APT signed-by keyring references' || v112_warn "Missing signed-by files: $(printf '%s' "$missing" | tr '\n' ' ')"
      ;;
    apk) [ -r /etc/apk/repositories ] && v112_pass 'APK repository file' || v112_warn 'APK repository file missing';;
    pacman) [ -r /etc/pacman.conf ] && v112_pass 'Pacman configuration' || v112_warn 'pacman.conf missing';;
    dnf|yum) [ -d /etc/yum.repos.d ] && v112_pass 'RPM repository directory' || v112_warn 'RPM repository directory missing';;
    *) v112_pass "Repository scan: native manager ${PKG_MGR:-unknown}";;
  esac
}

v112_scope_scan(){
  v112_check_command 'Host/RootFS scope guard' v104_main_scope_call
  v112_check_command 'System Configuration menu' v104_system_configuration_menu
  selected=$(active_rootfs 2>/dev/null || printf '/')
  [ -n "$selected" ] && v112_pass "Current RootFS context: $selected" || v112_fail 'RootFS context is empty'
}

v112_bug_audit(){
  mkdir -p "$(dirname "$V112_AUDIT_REPORT")" 2>/dev/null || true
  V112_AUDIT_RC=0
  {
    printf '%s %s — Menu and Bug Audit\n' "$PROGRAM" "$VERSION"
    printf 'Generated: %s\n\n' "$(date 2>/dev/null || printf unknown)"
  } >"$V112_AUDIT_REPORT"
  v112_shell_syntax_scan
  v112_declarative_menu_scan
  v112_menu_file_scan
  v112_editor_scan
  v112_package_menu_scan
  v112_rootfs_scan
  v112_repository_scan
  v112_scope_scan
  printf '\nResult: %s\n' "$([ "$V112_AUDIT_RC" -eq 0 ] && printf PASS || printf FAIL)" >>"$V112_AUDIT_REPORT"
  return "$V112_AUDIT_RC"
}

v112_bug_audit_ui(){
  if v112_bug_audit; then
    ui_text 'System Audit — passed' "$(cat "$V112_AUDIT_REPORT")"
  else
    ui_text 'System Audit — issues found' "$(cat "$V112_AUDIT_REPORT")"
  fi
}

# Terminal-safe editor override. It restores terminal state and propagates errors
# without ejecting the caller to the application entry menu.
edit_file(){
  f=$1
  d=$(dirname "$f")
  need_root || return 1
  [ -d "$d" ] || as_root mkdir -p "$d" || return 1
  [ -e "$f" ] || write_file "$f" 644 '' || return 1
  ed=$(v110_editor_command) || { ui_msg Editor 'No supported editor is installed. Use System Configuration → Editors to install Nano, Vim, Neovim, or Micro.'; return 1; }
  backup_file "$f"
  tmp="$TMP_DIR/edit.$$.${f##*/}"
  if [ -r "$f" ]; then cp -p "$f" "$tmp" 2>/dev/null || as_root cat "$f" >"$tmp" || return 1; else : >"$tmp"; fi
  chmod u+rw "$tmp" 2>/dev/null || true
  stty sane 2>/dev/null || true
  clear 2>/dev/null || printf '\033[2J\033[H'
  printf 'Editing %s with %s\nSave and exit to return to the previous menu.\n\n' "$f" "$ed"
  sh -c "$ed \"\$1\"" sh "$tmp"
  rc=$?
  stty sane 2>/dev/null || true
  if [ "$rc" -eq 0 ]; then
    if [ -w "$f" ]; then cat "$tmp" >"$f"; else as_root cp "$tmp" "$f"; fi
    rc=$?
  fi
  rm -f "$tmp"
  clear 2>/dev/null || true
  if [ "$rc" -ne 0 ]; then
    ui_msg Editor "Editing failed with status $rc. The original file and its backup were preserved."
    return "$rc"
  fi
  return 0
}

# Optimized host-only navigation. Frequently used sections remain visible;
# diagnostics and uncommon tools are grouped without removing functionality.
# Shell, editor and terminal configuration share one entry point.
v104_shell_editor_menu(){
  while :; do
    choice=$(ui_menu 'Shell, Editor and Terminal' 'Install and configure the interactive environment for the running system.' \
      shells 'Shells, prompts and frameworks' \
      editors 'Editors and editor configuration' \
      terminal 'Terminal applications and multiplexers' \
      back 'Back') || return 0
    case $choice in
      shells) shells_menu;;
      editors) editors_menu;;
      terminal) v1052_terminal_menu;;
      back) return 0;;
    esac
  done
}

v104_system_configuration_menu(){
  while :; do
    choice=$(ui_menu 'System Configuration' "$(printf '%s\nChanges on this screen affect only the running system (/).' "$(v104_system_status)")" \
      catalog 'Software Catalog — browse and configure system software' \
      packages 'Packages, package managers, repositories and keyrings' \
      environment 'Shells, editors and terminal applications' \
      network 'Networking, DNS, SSH and diagnostics' \
      services 'Services and startup' \
      users 'Users, passwords and sudo' \
      storage 'Storage, mounts, archives and backups' \
      performance 'Performance, optimization and maintenance' \
      advanced 'Additional and advanced system tools' \
      back 'Back') || return 0
    case $choice in
      catalog) v1100_software_catalog_menu;;
      packages) v104_system_packages_menu;;
      environment) v104_main_scope_call v104_shell_editor_menu;;
      network) v104_main_scope_call v1052_network_menu;;
      services) v104_main_scope_call service_center_v6;;
      users) v104_main_scope_call users_menu;;
      storage) v104_main_scope_call v1052_storage_menu;;
      performance) v104_main_scope_call performance_menu;;
      advanced) v104_main_scope_call v1052_advanced_system_menu;;
      back) return 0;;
    esac
  done
}
