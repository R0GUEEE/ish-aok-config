#!/bin/sh
# Common RootFS API (v8.2)
rootfs_api_path(){ r=${1:-$(active_rootfs 2>/dev/null)}; [ -n "$r" ] && [ -d "$r" ] && printf '%s\n' "$r"; }
rootfs_api_mount(){ r=$(rootfs_api_path "${1:-}") || return 1; command -v mount_rootfs_profile >/dev/null 2>&1 && mount_rootfs_profile "$r" "${2:-minimal}" || { root=$r; mount -t proc proc "$root/proc" 2>/dev/null || true; mount --bind /dev "$root/dev" 2>/dev/null || true; }; }
rootfs_api_unmount(){ r=$(rootfs_api_path "${1:-}") || return 1; for p in dev/pts dev proc sys run; do mountpoint -q "$r/$p" 2>/dev/null && umount "$r/$p" 2>/dev/null || true; done; }
rootfs_api_health(){ r=$(rootfs_api_path "${1:-}") || return 1; old=$(active_rootfs 2>/dev/null || true); set_active_rootfs "$r"; rootfs_health_report; rc=$?; [ -n "$old" ] && set_active_rootfs "$old"; return $rc; }
rootfs_api_snapshot(){ r=$(rootfs_api_path "${1:-}") || return 1; old=$(active_rootfs 2>/dev/null || true); set_active_rootfs "$r"; rootfs_manager_export; rc=$?; [ -n "$old" ] && set_active_rootfs "$old"; return $rc; }
rootfs_api_archive(){ rootfs_api_snapshot "$@"; }
rootfs_api_diff(){ a=$1; b=$2; [ -d "$a" ] && [ -d "$b" ] || return 1; diff -qr "$a/etc" "$b/etc" 2>/dev/null; }
rootfs_api_report(){ r=$(rootfs_api_path "${1:-}") || return 1; old=$(active_rootfs 2>/dev/null || true); set_active_rootfs "$r"; rootfs_report_generator 2>/dev/null || rootfs_health_report; rc=$?; [ -n "$old" ] && set_active_rootfs "$old"; return $rc; }
