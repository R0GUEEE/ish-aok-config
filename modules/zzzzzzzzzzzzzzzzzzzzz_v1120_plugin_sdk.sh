#!/bin/sh
# v11.2.0 SDK menus and compatibility overrides.

v112_plugin_generator_ui(){
  _id=$(ui_input 'Plugin Generator' 'Plugin ID (lowercase letters, digits, ._-):' 'example-plugin') || return
  _name=$(ui_input 'Plugin Generator' 'Display name:' "$_id") || return
  _author=$(ui_input 'Plugin Generator' 'Author:' "${USER:-unknown}") || return
  _dest=$(ui_input 'Plugin Generator' 'Destination directory:' "${HOME:-/root}/$_id") || return
  if v112_plugin_create "$_id" "$_dest" "$_name" "$_author"; then ui_msg 'Plugin Generator' "Created plugin:\n$_dest"; else ui_msg 'Plugin Generator' 'Could not create plugin. Check the ID and destination.'; fi
}
v112_distribution_generator_ui(){
  _id=$(ui_input 'Distribution Generator' 'Distribution ID:' 'mylinux') || return
  _pm=$(ui_input 'Distribution Generator' 'Package manager:' 'apt') || return
  _backend=$(ui_input 'Distribution Generator' 'Bootstrap backend:' 'debootstrap') || return
  _arches=$(ui_input 'Distribution Generator' 'Architectures (comma separated):' 'arm64,amd64,i386,riscv64') || return
  _dest=$(ui_input 'Distribution Generator' 'Destination directory:' "${HOME:-/root}/$_id-distribution") || return
  if v112_distribution_create "$_id" "$_dest" "$_pm" "$_backend" "$_arches"; then ui_msg 'Distribution Generator' "Created distribution SDK:\n$_dest"; else ui_msg 'Distribution Generator' 'Could not create distribution definition.'; fi
}
v112_validate_plugin_ui(){ _p=$(ui_input 'Validate Plugin' 'Plugin directory or manifest:' '') || return; [ -d "$_p" ] && _p=$(v112_plugin_manifest "$_p"); ui_text 'Plugin Validation' "$(v112_plugin_validate "$_p" 2>&1 || true)"; }
v112_validate_distribution_ui(){ _p=$(ui_input 'Validate Distribution' 'Distribution SDK directory:' '') || return; ui_text 'Distribution Validation' "$(v112_distribution_validate "$_p" 2>&1 || true)"; }
v112_plugin_manager_menu(){
  while :; do
    v112_plugin_scan
    _c=$(ui_menu 'Plugin Manager' 'Install, inspect, enable, disable, remove, and validate v11.2 plugins.' installed 'Installed plugins' catalog 'Available catalog' install 'Install local plugin directory' enable 'Enable plugin' disable 'Disable plugin' remove 'Remove user plugin' validate 'Validate plugin' rescan 'Rescan plugins' back 'Back') || return 0
    case $_c in
      installed) ui_text 'Installed Plugins' "$(cat "$V112_INDEX" 2>/dev/null || echo 'No plugins installed.')";;
      catalog) ui_text 'Plugin Catalog' "$(v112_catalog_report)";;
      install) _p=$(ui_input 'Install Plugin' 'Plugin directory:' '') || continue; v112_plugin_install_dir "$_p" && ui_msg Plugins 'Plugin installed.' || ui_msg Plugins 'Plugin installation failed.';;
      enable|disable|remove) _id=$(ui_input 'Plugin' 'Plugin ID:' '') || continue; case $_c in enable) v112_plugin_enable "$_id";; disable) v112_plugin_disable "$_id";; remove) v112_plugin_remove "$_id";; esac; v112_plugin_scan;;
      validate) v112_validate_plugin_ui;; rescan) v112_plugin_scan; ui_msg Plugins 'Plugin index refreshed.';; back) return 0;;
    esac
  done
}
v112_developer_menu(){
  while :; do
    _c=$(ui_menu 'SDK Developer Tools' 'Create and validate extensions without modifying the core.' plugin 'Plugin generator' distribution 'Distribution generator' validate_plugin 'Validate plugin' validate_distribution 'Validate distribution' catalog 'Catalog report' tests 'Run SDK self-test' docs 'View SDK documentation' back 'Back') || return 0
    case $_c in
      plugin) v112_plugin_generator_ui;; distribution) v112_distribution_generator_ui;; validate_plugin) v112_validate_plugin_ui;; validate_distribution) v112_validate_distribution_ui;; catalog) ui_text 'Plugin Catalog' "$(v112_catalog_report)";; tests) ui_text 'SDK Self-test' "$(sh "$ISH_AOK_CONFIG_ROOT/tests/v1120_plugin_sdk.sh" 2>&1 || true)";; docs) ui_text 'Plugin SDK' "$(cat "$ISH_AOK_CONFIG_ROOT/docs/PLUGIN-SDK.md" 2>/dev/null)";; back) return 0;;
    esac
  done
}
sdk_center(){
  while :; do
    _c=$(ui_menu 'Modules, Plugins and SDK' 'v11.2 stable plugin and distribution development interface.' manager 'Plugin Manager' legacy 'Legacy module browser' developer 'SDK Developer Tools' catalog 'Official catalog format' docs 'Developer documentation' back 'Back') || return 0
    case $_c in manager) v112_plugin_manager_menu;; legacy) sdk_modules_menu;; developer) v112_developer_menu;; catalog) ui_text 'Plugin Catalog' "$(v112_catalog_report)";; docs) ui_text 'SDK Documentation' "$(cat "$ISH_AOK_CONFIG_ROOT/docs/PLUGIN-SDK.md")";; back) return 0;; esac
  done
}

# Load enabled v11.2 user plugins after the SDK functions are available.
v112_plugin_source_all 2>/dev/null || true
