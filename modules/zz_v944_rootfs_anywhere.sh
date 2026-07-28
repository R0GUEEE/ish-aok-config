#!/bin/sh

V944_ROOTFS_PATH_DIR=${V944_ROOTFS_PATH_DIR:-$STATE_DIR/rootfs-anywhere-v944}
V944_ROOTFS_RECENT=$V944_ROOTFS_PATH_DIR/recent-paths
mkdir -p "$V944_ROOTFS_PATH_DIR" 2>/dev/null || true

rootfs_anywhere_canonical(){
  p=$1
  [ -d "$p" ] || return 1
  (CDPATH= cd -P -- "$p" 2>/dev/null && pwd)
}

rootfs_anywhere_looks_valid(){
  r=$1
  [ "$r" = / ] && return 0
  [ -d "$r/etc" ] || return 1
  [ -x "$r/bin/sh" ] || [ -x "$r/usr/bin/sh" ] || [ -x "$r/bin/bash" ] || return 1
  [ -r "$r/etc/os-release" ] || [ -r "$r/usr/lib/os-release" ] || [ -r "$r/etc/passwd" ] || return 1
}

rootfs_anywhere_remember(){
  p=$1
  mkdir -p "$V944_ROOTFS_PATH_DIR" 2>/dev/null || true
  t=$TMP_DIR/rootfs-anywhere-recent
  { printf '%s\n' "$p"; [ -r "$V944_ROOTFS_RECENT" ] && cat "$V944_ROOTFS_RECENT"; } |
    awk 'NF && !seen[$0]++' | head -20 >"$t"
  mv "$t" "$V944_ROOTFS_RECENT"
}

rootfs_anywhere_activate(){
  raw=$1
  [ -n "$raw" ] || return 1
  path=$(rootfs_anywhere_canonical "$raw") || { ui_msg RootFS "Directory not found or inaccessible:\n$raw"; return 1; }

  if ! rootfs_anywhere_looks_valid "$path"; then
    ui_yesno RootFS "The selected directory does not look like a complete Linux RootFS:\n\n$path\n\nExpected markers include etc/, a shell, and os-release or passwd. Register and activate it anyway?" || return 1
  fi

  rootfs_register "$path" || { ui_msg RootFS "Could not register:\n$path"; return 1; }
  rootfs_registry_refresh "$path" >/dev/null 2>&1 || true
  set_active_rootfs "$path" || { ui_msg RootFS "Could not activate:\n$path"; return 1; }
  command -v v90_context_set >/dev/null 2>&1 && v90_context_set rootfs "$path" || true
  command -v activity_add >/dev/null 2>&1 && activity_add rootfs "Selected RootFS from $path" || true
  rootfs_anywhere_remember "$path"
  ui_msg RootFS "Active RootFS set to:\n$path"
}

rootfs_anywhere_recent_select(){
  [ -s "$V944_ROOTFS_RECENT" ] || { ui_msg RootFS 'No recently selected external RootFS paths.'; return 1; }
  set --
  while IFS= read -r p; do
    [ -d "$p" ] || continue
    set -- "$@" "$p" "$p"
  done <"$V944_ROOTFS_RECENT"
  [ "$#" -gt 0 ] || { ui_msg RootFS 'No recent RootFS paths are currently available.'; return 1; }
  ui_menu 'Recent RootFS paths' 'Select a previously used path.' "$@"
}

rootfs_anywhere_directory_browser(){
  current=${1:-/}
  current=$(rootfs_anywhere_canonical "$current" 2>/dev/null || printf '/')
  while :; do
    set -- choose 'Use this directory'
    [ "$current" != / ] && set -- "$@" parent '.. (parent directory)'
    for d in "$current"/* "$current"/.[!.]* "$current"/..?*; do
      [ -d "$d" ] || continue
      base=$(basename "$d")
      set -- "$@" "$d" "$base/"
    done
    choice=$(ui_menu 'Browse for RootFS' "Current directory:\n$current\n\nOpen a directory or use the current directory." "$@" back Back) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return 1; };
    case $choice in
      choose) printf '%s' "$current"; return 0;;
      parent) current=$(dirname "$current");;
      *) [ -d "$choice" ] && current=$(rootfs_anywhere_canonical "$choice") || true;;
    esac
  done
}

rootfs_select_anywhere(){
  start=$(active_rootfs 2>/dev/null || printf '/')
  while :; do
    choice=$(ui_menu 'Select RootFS from anywhere' "Current active RootFS: $start" path 'Enter an absolute path' browse 'Browse the filesystem' recent 'Choose a recent external path' registered 'Choose a registered RootFS' back Back) || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $choice in
      path)
        p=$(ui_input RootFS 'Absolute path to an existing RootFS directory' "$start") || continue
        rootfs_anywhere_activate "$p" && return
        ;;
      browse)
        p=$(rootfs_anywhere_directory_browser "$start") || continue
        rootfs_anywhere_activate "$p" && return
        ;;
      recent)
        p=$(rootfs_anywhere_recent_select) || continue
        rootfs_anywhere_activate "$p" && return
        ;;
      registered)
        p=$(rootfs_select_registered) || continue
        rootfs_anywhere_activate "$p" && return
        ;;
    esac
  done
}
