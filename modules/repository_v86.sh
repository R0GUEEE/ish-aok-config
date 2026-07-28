#!/bin/sh

v86_show_report(){ r=$(active_rootfs 2>/dev/null || echo /); out=$(repo_v86_report "$r") || { ui_msg Error 'Unable to create repository report.'; return 1; }; ui_text 'Repository and package policy' "$(cat "$out")"; }
v86_show_files(){ r=$(active_rootfs 2>/dev/null || echo /); files=$(repo_v86_files "$r"); [ -n "$files" ] || files='No repository files detected.'; ui_text 'Repository files' "RootFS: $r\n\n$files"; }
v86_snapshot(){ r=$(active_rootfs 2>/dev/null || echo /); out=$(repo_v86_snapshot "$r") || { ui_msg Error 'Unable to create repository snapshot.'; return 1; }; ui_msg 'Repository snapshot' "Created: $out"; }
v86_hold_package(){ r=$(active_rootfs 2>/dev/null || echo /); pkg=$(ui_input 'Package policy' 'Package name to hold or exclude:' '') || return; [ -n "$pkg" ] || return; aok_confirm "Apply a hold/exclusion for $pkg in $r?" || return; run_capture 'Apply package hold' repo_v86_hold "$r" "$pkg"; }
v86_repository_policy_menu(){
  while :; do
    c=$(ui_menu 'Repository & Package Policy' "Active: $(active_rootfs) | Manager: $(repo_v86_manager "$(active_rootfs)")" \
      report 'Audit repositories, signatures and package policy' \
      files 'List detected repository configuration files' \
      snapshot 'Record checksums of repository configuration' \
      hold 'Hold or exclude a package' \
      native 'Open native repository and mirror tools' \
      packages 'Open unified package manager') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in report) v86_show_report;; files) v86_show_files;; snapshot) v86_snapshot;; hold) v86_hold_package;; native) repositories_menu;; packages) package_center_v6;; esac
  done
}
