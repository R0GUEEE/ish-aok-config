#!/bin/sh
# v11.3.0 RootFS lifecycle and workspace UI.

v113_pick_rootfs(){
  v113_library_scan >/dev/null 2>&1 || true
  _id=$(ui_input 'Select RootFS' 'Enter registered RootFS ID or name:' '') || return 1
  _p=$(v113_library_path "$_id"); [ -n "$_p" ] || { ui_msg RootFS 'No matching RootFS was found.'; return 1; }
  printf '%s\n' "$_p"
}
v113_rootfs_library_menu(){
  while :; do
    _c=$(ui_menu 'RootFS Library' 'Central inventory for built, imported, and existing filesystems.' scan 'Scan common locations' list 'List registered RootFSes' register 'Register a RootFS path' info 'RootFS information' validate 'Validation scorecard' snapshot 'Create snapshot' compare 'Compare two RootFSes' package 'Run package operation' remove 'Remove registry entry' back 'Back') || return 0
    case $_c in
      scan) v113_library_scan; ui_text 'RootFS Library' "$(v113_library_report)";; list) ui_text 'RootFS Library' "$(v113_library_report)";;
      register) _p=$(ui_input 'Register RootFS' 'Filesystem path:' '') || continue; _n=$(ui_input 'Register RootFS' 'Display name:' "$(basename "$_p")") || continue; _id=$(v113_library_register "$_p" "$_n" 2>&1) && ui_msg RootFS "Registered: $_id" || ui_msg RootFS "Registration failed:\n$_id";;
      info) _id=$(ui_input 'RootFS Information' 'RootFS ID or name:' '') || continue; ui_text 'RootFS Information' "$(v113_library_info "$_id")";;
      validate) _p=$(v113_pick_rootfs) || continue; _r=$(v113_validate_rootfs "$_p"); ui_text 'Validation Scorecard' "$(cat "$_r")";;
      snapshot) _p=$(v113_pick_rootfs) || continue; _n=$(ui_input Snapshot 'Snapshot name:' "snapshot-$(v113_id)") || continue; _id=$(v113_snapshot_create "$_p" "$_n" 2>&1) && ui_msg Snapshot "Created: $_id" || ui_msg Snapshot "Failed: $_id";;
      compare) _a=$(v113_pick_rootfs) || continue; _b=$(v113_pick_rootfs) || continue; _r=$(v113_compare "$_a" "$_b"); ui_text 'RootFS Comparison' "$(cat "$_r")";;
      package) _p=$(v113_pick_rootfs) || continue; _op=$(ui_menu 'Package Operation' 'The command executes inside the selected RootFS.' install Install remove Remove back Back) || continue; [ "$_op" = back ] && continue; _pkg=$(ui_input 'Package Operation' 'Package name:' '') || continue; _cmd=$(v113_package_command "$_p" "$_op" "$_pkg" 2>&1) || { ui_msg Packages "No supported package manager was found.\n$_cmd"; continue; }; ui_yesno Packages "Run inside $_p?\n\n$_cmd" && { v113_package_apply "$_p" "$_op" "$_pkg" && ui_msg Packages 'Operation completed.' || ui_msg Packages 'Operation failed.'; };;
      remove) _id=$(ui_input 'Remove Registry Entry' 'RootFS ID:' '') || continue; ui_yesno RootFS 'Remove only the registry entry? The filesystem will not be deleted.' && v113_library_remove "$_id";; back) return 0;;
    esac
  done
}
v113_workspace_menu(){
  while :; do
    _c=$(ui_menu 'Workspace Manager' 'Reusable shell, editor, package, environment, mount, plugin, and startup settings.' list 'List workspaces' create 'Create from template' inspect 'Inspect workspace' clone 'Clone workspace' export 'Export workspace' delete 'Delete workspace' templates 'Show built-in templates' back 'Back') || return 0
    case $_c in
      list) ui_text Workspaces "$(v113_workspace_list)";;
      create) _name=$(ui_input Workspace 'Workspace name:' 'development') || continue; _root=$(v113_pick_rootfs) || continue; _tpl=$(ui_menu Templates 'Select a template.' minimal Minimal cpp 'C/C++' rust Rust python Python go Go node Node.js swift Swift embedded Embedded server Server recovery Recovery back Back) || continue; [ "$_tpl" = back ] && continue; _id=$(v113_workspace_create "$_name" "$_root" "$_tpl" 2>&1) && ui_msg Workspace "Created: $_id" || ui_msg Workspace "Failed: $_id";;
      inspect) _id=$(ui_input Workspace 'Workspace ID:' '') || continue; _f=$(v113_workspace_file "$_id"); [ -r "$_f" ] && ui_text Workspace "$(cat "$_f"; echo; for x in environment mounts startup aliases; do echo "[$x]"; cat "$(dirname "$_f")/$x"; done)" || ui_msg Workspace 'Not found.';;
      clone) _id=$(ui_input Workspace 'Source workspace ID:' '') || continue; _new=$(ui_input Workspace 'New workspace name:' '') || continue; v113_workspace_clone "$_id" "$_new" && ui_msg Workspace 'Cloned.' || ui_msg Workspace 'Clone failed.';;
      export) _id=$(ui_input Workspace 'Workspace ID:' '') || continue; _dest=$(ui_input Workspace 'Export archive:' "${HOME:-/root}/$_id-workspace.tar.gz") || continue; v113_workspace_export "$_id" "$_dest" && ui_msg Workspace "Exported: $_dest" || ui_msg Workspace 'Export failed.';;
      delete) _id=$(ui_input Workspace 'Workspace ID:' '') || continue; ui_yesno Workspace 'Delete this workspace metadata?' && v113_workspace_delete "$_id";;
      templates) ui_text Templates 'minimal\ncpp\nrust\npython\ngo\nnode\nswift\nembedded\nserver\nrecovery';; back) return 0;;
    esac
  done
}
v113_snapshot_menu(){
  while :; do
    _c=$(ui_menu 'Snapshot Manager' 'Portable archive snapshots of repositories, package databases, users, SSH, and shell configuration.' list List create Create restore Restore validate Validate export Export delete Delete back Back) || return 0
    case $_c in
      list) ui_text Snapshots "$(v113_snapshot_list)";; create) _p=$(v113_pick_rootfs) || continue; _n=$(ui_input Snapshot 'Name:' "snapshot-$(v113_id)") || continue; _id=$(v113_snapshot_create "$_p" "$_n" 2>&1) && ui_msg Snapshot "Created: $_id" || ui_msg Snapshot "Failed: $_id";;
      restore) _id=$(ui_input Snapshot 'Snapshot ID:' '') || continue; _target=$(ui_input Snapshot 'Restore target RootFS:' '') || continue; ui_yesno Snapshot 'Restore files into the selected target?' && { v113_snapshot_restore "$_id" "$_target" && ui_msg Snapshot Restored. || ui_msg Snapshot 'Restore failed.'; };;
      validate) _id=$(ui_input Snapshot 'Snapshot ID:' '') || continue; v113_snapshot_validate "$_id" && ui_msg Snapshot 'Checksum valid.' || ui_msg Snapshot 'Validation failed.';;
      export) _id=$(ui_input Snapshot 'Snapshot ID:' '') || continue; _m=$V113_SNAPSHOTS/metadata/$_id.conf; _a=$(v113_file_value "$_m" archive); _dest=$(ui_input Snapshot 'Export destination:' "${HOME:-/root}/$(basename "$_a")") || continue; cp "$_a" "$_dest" && ui_msg Snapshot "Exported: $_dest" || ui_msg Snapshot 'Export failed.';;
      delete) _id=$(ui_input Snapshot 'Snapshot ID:' '') || continue; ui_yesno Snapshot 'Delete snapshot archive and metadata?' && v113_snapshot_delete "$_id";; back) return 0;; esac
  done
}
v113_image_menu(){
  while :; do
    _c=$(ui_menu 'Image Library' 'Catalog local build artifacts and imported RootFS archives.' list List register Register verify Verify back Back) || return 0
    case $_c in list) ui_text Images "$(v113_image_report)";; register) _p=$(ui_input Images 'Archive path:' '') || continue; _id=$(v113_image_register "$_p" 2>&1) && ui_msg Images "Registered: $_id" || ui_msg Images "Failed: $_id";; verify) _id=$(ui_input Images 'Image ID or name:' '') || continue; v113_image_verify "$_id" && ui_msg Images 'Checksum valid.' || ui_msg Images 'Checksum failed.';; back) return 0;; esac
  done
}
v113_official_plugins_menu(){
  while :; do
    _c=$(ui_menu 'Official Plugins' 'SDK-compliant first-party package and configuration plugins.' list 'List included plugins' install 'Install plugin to user plugin directory' validate 'Validate all official plugins' back Back) || return 0
    case $_c in
      list) _out=$(for _m in "$V113_OFFICIAL_PLUGINS"/*/plugin.yaml; do [ -r "$_m" ] || continue; printf '%-18s %-14s %s\n' "$(v112_meta_get "$_m" id)" "$(v112_meta_get "$_m" category)" "$(v112_meta_get "$_m" description)"; done); ui_text 'Official Plugins' "$_out";;
      install) _id=$(ui_input Plugins 'Plugin ID:' '') || continue; [ -d "$V113_OFFICIAL_PLUGINS/$_id" ] && v112_plugin_install_dir "$V113_OFFICIAL_PLUGINS/$_id" && ui_msg Plugins Installed. || ui_msg Plugins 'Installation failed.';;
      validate) _out=; for _m in "$V113_OFFICIAL_PLUGINS"/*/plugin.yaml; do [ -r "$_m" ] || continue; _out="$_out$(basename "$(dirname "$_m")"): $(v112_plugin_validate "$_m" 2>&1)\n"; done; ui_text 'Plugin Validation' "$_out";; back) return 0;; esac
  done
}
v113_management_menu(){
  v113_init >/dev/null 2>&1 || true
  while :; do
    _c=$(ui_menu 'RootFS & Workspace Management' 'v11.3 portable lifecycle management for iSH-AOK filesystems.' library 'RootFS Library' workspaces 'Workspace Manager' snapshots 'Snapshot Manager' images 'Image Library' plugins 'Official Plugins' performance 'Performance Dashboard' builder 'RootFS Builder' legacy 'Legacy RootFS tools' back Back) || return 0
    case $_c in library) v113_rootfs_library_menu;; workspaces) v113_workspace_menu;; snapshots) v113_snapshot_menu;; images) v113_image_menu;; plugins) v113_official_plugins_menu;; performance) ui_text Performance "$(v113_performance_report)";; builder) v1110_builder_dashboard;; legacy) v104_manage_rootfs_menu;; back) return 0;; esac
  done
}

# Register successful staged builds after validation/export.
plugin_post_build_v113(){ v113_pipeline_register "$1"; }

v1100_builder_dashboard(){ v1110_builder_dashboard; }
main_menu(){
  while :; do
    _c=$(ui_menu "$PROGRAM $VERSION" "$(printf 'System: %s | %s | %s\nActive RootFS: %s' "${DISTRO_ID:-unknown}" "${ARCH:-unknown}" "${PKG_MGR:-unknown}" "$(active_rootfs 2>/dev/null || printf none)")" builder 'RootFS Builder' manage 'RootFS & Workspaces' system 'System Configuration' catalog 'Software Catalog' plugins 'Modules, Plugins & SDK' health 'Health & Diagnostics' search Search settings Settings about About exit Exit) || return 0
    case $_c in builder) v1110_builder_dashboard;; manage) v113_management_menu;; system) v104_system_configuration_menu;; catalog) v1100_software_catalog_menu;; plugins) sdk_center;; health) v112_diagnostics_menu;; search) v990_navigation_search_menu;; settings) v103_settings_menu;; about) ui_text About "iSH-AOK Config $VERSION\n\nv11.3 RootFS Library, workspaces, snapshots, image catalog, validation scorecards, and official SDK plugins.\n\nProject: https://github.com/emkey1/ish-AOK";; exit) return 0;; esac
  done
}
workspace_dashboard_v90(){ main_menu; }
workspace_dashboard_v91(){ main_menu; }
workspace_dashboard_v73(){ main_menu; }

# Final pipeline override: preserve v11.1 checkpoints and register successful RootFSes.
v1110_pipeline_run(){
  ws=$1
  v1110_backend_load || return 1
  command -v v112_plugin_run_hook >/dev/null 2>&1 && v112_plugin_run_hook pre-build "$ws" || true
  for stage in $V1110_STAGE_ORDER; do
    v1110_stage_done "$ws" "$stage" && continue
    v1110_run_stage "$ws" "$stage" || { v1110_history_add "$ws" failed; return 1; }
  done
  v1110_state_set "$ws" STATUS complete
  v1110_state_set "$ws" COMPLETED_AT "$(v1110_now)"
  v1110_history_add "$ws" complete
  v1101_manifest_generate >/dev/null 2>&1 || true
  v113_pipeline_register "$ws" >/dev/null 2>&1 || true
  command -v v112_plugin_run_hook >/dev/null 2>&1 && v112_plugin_run_hook post-build "$ws" || true
  return 0
}

v113_lifecycle_menu(){
  while :; do
    _c=$(ui_menu 'RootFS Lifecycle' 'Clone, export, rename, tag, delete, compare, and perform bulk package operations.' clone Clone export Export rename Rename tag Tag delete 'Delete filesystem' bulk 'Multi-RootFS package operation' compare 'Formatted comparison' launch 'Generate workspace launcher' back Back) || return 0
    case $_c in
      clone) _id=$(ui_input RootFS 'Source RootFS ID:' '') || continue; _dest=$(ui_input RootFS 'Clone destination:' '') || continue; _name=$(ui_input RootFS 'Clone name:' "$(basename "$_dest")") || continue; _new=$(v113_library_clone "$_id" "$_dest" "$_name" 2>&1) && ui_msg RootFS "Clone registered: $_new" || ui_msg RootFS "Clone failed: $_new";;
      export) _id=$(ui_input RootFS 'RootFS ID:' '') || continue; _dest=$(ui_input RootFS 'Export archive:' "${HOME:-/root}/rootfs-$(v113_id).tar.gz") || continue; v113_library_export "$_id" "$_dest" && { v113_image_register "$_dest" >/dev/null 2>&1 || true; ui_msg RootFS "Exported: $_dest"; } || ui_msg RootFS 'Export failed.';;
      rename) _id=$(ui_input RootFS 'RootFS ID:' '') || continue; _name=$(ui_input RootFS 'New display name:' '') || continue; v113_library_update_field "$_id" name "$_name" && ui_msg RootFS Renamed.;;
      tag) _id=$(ui_input RootFS 'RootFS ID:' '') || continue; _tags=$(ui_input RootFS 'Comma-separated tags:' '') || continue; v113_library_update_field "$_id" tags "$_tags" && ui_msg RootFS 'Tags updated.';;
      delete) _id=$(ui_input RootFS 'RootFS ID:' '') || continue; ui_yesno RootFS 'Permanently remove the registered filesystem? Protected and system paths are refused.' && { v113_library_delete_filesystem "$_id" && ui_msg RootFS Deleted. || ui_msg RootFS 'Deletion refused or failed.'; };;
      bulk) _ids=$(ui_input Packages 'Comma-separated RootFS IDs:' '') || continue; _op=$(ui_menu Packages 'Select operation.' install Install remove Remove back Back) || continue; [ "$_op" = back ] && continue; _pkg=$(ui_input Packages 'Package name:' '') || continue; _out=$(v113_bulk_package_apply "$_ids" "$_op" "$_pkg" 2>&1) && ui_text Packages "${_out:-Completed.}" || ui_text Packages "Operation completed with failures:\n$_out";;
      compare) _a=$(v113_pick_rootfs) || continue; _b=$(v113_pick_rootfs) || continue; _fmt=$(ui_menu Compare 'Report format.' text Text markdown Markdown html HTML back Back) || continue; [ "$_fmt" = back ] && continue; _r=$(v113_compare_format "$_a" "$_b" "$_fmt") && ui_text Compare "Saved: $_r\n\n$(cat "$_r")";;
      launch) _id=$(ui_input Workspace 'Workspace ID:' '') || continue; _r=$(v113_workspace_launch_script "$_id" 2>&1) && ui_msg Workspace "Launcher generated: $_r" || ui_msg Workspace "Failed: $_r";;
      back) return 0;;
    esac
  done
}

# Final v11.3 management menu with the complete lifecycle surface.
v113_management_menu(){
  v113_init >/dev/null 2>&1 || true
  while :; do
    _c=$(ui_menu 'RootFS & Workspace Management' 'Portable lifecycle management for iSH-AOK filesystems.' library 'RootFS Library' lifecycle 'Clone, export, tags, delete, bulk packages' workspaces 'Workspace Manager' snapshots 'Snapshot Manager' images 'Image Library' plugins 'Official Plugins' performance 'Performance Dashboard' builder 'RootFS Builder' legacy 'Legacy RootFS tools' back Back) || return 0
    case $_c in library) v113_rootfs_library_menu;; lifecycle) v113_lifecycle_menu;; workspaces) v113_workspace_menu;; snapshots) v113_snapshot_menu;; images) v113_image_menu;; plugins) v113_official_plugins_menu;; performance) ui_text Performance "$(v113_performance_report)";; builder) v1110_builder_dashboard;; legacy) v104_manage_rootfs_menu;; back) return 0;; esac
  done
}
