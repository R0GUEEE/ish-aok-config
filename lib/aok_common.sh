#!/bin/sh
AOK_STATE_DIR=$STATE_DIR/aok
AOK_CONTEXT_FILE=$AOK_STATE_DIR/active-rootfs
AOK_SNAPSHOT_DIR=$AOK_STATE_DIR/snapshots
AOK_PROFILE_DIR=$AOK_STATE_DIR/profiles
AOK_PATCH_DIR=$AOK_STATE_DIR/patches
mkdir -p "$AOK_STATE_DIR" "$AOK_SNAPSHOT_DIR" "$AOK_PROFILE_DIR" "$AOK_PATCH_DIR" 2>/dev/null || true

active_rootfs(){ [ -s "$AOK_CONTEXT_FILE" ] && cat "$AOK_CONTEXT_FILE" || printf '/'; }
set_active_rootfs(){ r=$1; [ -d "$r" ] || return 1; printf '%s\n' "$r" >"$AOK_CONTEXT_FILE"; }
root_path(){ r=$(active_rootfs); case $1 in /*) [ "$r" = / ] && printf '%s' "$1" || printf '%s%s' "$r" "$1";; *) printf '%s/%s' "$r" "$1";; esac; }
root_label(){ r=$(active_rootfs); [ "$r" = / ] && printf 'host' || basename "$r"; }
aok_confirm(){ ui_yesno 'Confirm AOK action' "$1\n\nActive rootfs: $(active_rootfs)"; }
aok_need_rootfs(){ r=$(active_rootfs); [ -d "$r" ] || { ui_msg RootFS 'Select a valid active rootfs first.'; return 1; }; }
aok_safe_name(){ printf '%s' "$1" | sed 's#[^A-Za-z0-9._-]#_#g'; }
aok_find_roots(){
  { [ -f /etc/os-release ] && echo /; find /AOK /opt/AOK /root /mnt /media /var/lib -maxdepth 5 -type f -path '*/etc/os-release' 2>/dev/null | sed 's#/etc/os-release$##'; } | awk '!seen[$0]++'
}
aok_root_os(){ r=$1; f=$r/etc/os-release; [ "$r" = / ] && f=/etc/os-release; [ -r "$f" ] && . "$f" 2>/dev/null; printf '%s' "${PRETTY_NAME:-${ID:-unknown}}"; unset PRETTY_NAME ID VERSION_ID VERSION_CODENAME 2>/dev/null || true; }
aok_root_arch(){ r=$1; for b in "$r/bin/sh" "$r/usr/bin/env"; do [ -e "$b" ] && { file "$b" 2>/dev/null | sed 's/.*: //'; return; }; done; echo unknown; }
aok_mountpoint(){ grep -qs " $1 " /proc/mounts 2>/dev/null; }
aok_run_in_root(){ r=$(active_rootfs); if [ "$r" = / ]; then "$@"; elif have chroot; then as_root chroot "$r" "$@"; else return 127; fi; }
aok_capture(){ title=$1; shift; run_capture "$title" "$@"; }
aok_report_file(){ printf '%s/%s-%s.txt' "$REPORT_DIR" "$1" "$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)"; }
aok_backup_root_config(){
  r=$(active_rootfs); n=$(aok_safe_name "$(root_label)"); o="$AOK_SNAPSHOT_DIR/${n}-config-$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now).tar.gz"
  [ "$r" = / ] && base=/ || base=$r
  tar -czf "$o" -C "$base" etc home/root root/.profile root/.bashrc 2>/dev/null || tar -czf "$o" -C "$base" etc 2>/dev/null || return 1
  printf '%s' "$o"
}
aok_command_preview(){ ui_text 'Command preview' "$*"; }
aok_install_hint(){ ui_msg Missing "Required command not found: $1\nUse Package Manager > Install package, or install the distribution package that provides it."; }
aok_select_root(){
  roots=$(aok_find_roots); [ -n "$roots" ] || { ui_msg RootFS 'No root filesystems found.'; return 1; }
  set --
  oldifs=$IFS; IFS='\n'
  for r in $roots; do [ -n "$r" ] && set -- "$@" "$r" "$(aok_root_os "$r")"; done
  IFS=$oldifs
  c=$(ui_menu 'Select active rootfs' 'All AOK actions use this root until changed.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return 1; };
  set_active_rootfs "$c" && ui_msg RootFS "Active rootfs set to:\n$c"
}
aok_write_script(){ name=$1; body=$2; out=$CURRENT_HOME/bin/$name; mkdir -p "$CURRENT_HOME/bin"; write_file "$out" 755 "$body"; ui_msg Script "$out"; }
