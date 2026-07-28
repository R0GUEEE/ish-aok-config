#!/bin/sh
# v11.0.0 milestone 1: modular foundation and RootFS-first navigation.

v1100_plugins_menu(){
  while :; do
    inventory=$(v11_plugin_inventory 2>/dev/null || true)
    c=$(ui_menu 'Modules & Plugins' 'Manifest-based module discovery. Disabled modules are listed but never sourced automatically.' \
      inventory 'Show discovered v11 modules' legacy 'Manage shell/editor plugins' sdk 'Open module SDK tools' back 'Back') || return 0
    case $c in
      inventory) [ -n "$inventory" ] && ui_text 'v11 module inventory' "$inventory" || ui_msg 'v11 module inventory' 'No v11 modules were discovered.';;
      legacy) plugin_manager_menu;; sdk) sdk_modules_menu;; back) return 0;;
    esac
  done
}

v1100_software_catalog_menu(){
  while :; do
    c=$(ui_menu 'Software Catalog' 'Central metadata supplies software labels, categories, descriptions, and configuration routes.' \
      browse 'Browse catalog report' packages 'Open package groups' search 'Search all actions' back 'Back') || return 0
    case $c in
      browse) ui_text 'Software Catalog' "$(v11_catalog_report)";;
      packages) v107_curated_groups_menu;; search) v990_navigation_search_menu;; back) return 0;;
    esac
  done
}

v1100_builder_dashboard(){
  while :; do
    profile=${V89_ACTIVE_PROFILE:-standard}
    c=$(ui_menu 'RootFS Builder' "Target: ${V102_DISTRO:-not selected} | Architecture: ${V102_ARCH:-not selected}\nProfile: $profile\nKeyring cache: ${V111_KEYRING_CACHE:-/var/cache/ish-aok-config/keyrings}" \
      wizard 'Start guided build wizard' profiles 'Build profiles and package manifests' \
      keyrings 'Target-distribution keyrings and cache' paths 'Build destination and artifact paths' \
      validate 'Validate current build plan' execute 'Build RootFS' manage 'Manage existing RootFS filesystems' \
      capabilities 'Show distribution capability matrix' advanced 'Advanced builder tools' back 'Back') || return 0
    case $c in
      wizard) v102_new_rootfs_wizard;; profiles) v89_build_profiles_menu;; keyrings) v110_rootfs_keyrings_menu;;
      paths) v93_build_paths_menu;;
      validate) v88_build_plan_report; ui_text 'Build validation' "$(cat "$V88_BUILD_PLAN_REPORT" 2>/dev/null || printf 'No build plan report was generated.')";;
      execute) v88_build_execution_menu;; manage) v104_manage_rootfs_menu;;
      capabilities) ui_text 'Capability Matrix' "$(v11_capability_report)";;
      advanced) v91_menu_run build_advanced;; back) return 0;;
    esac
  done
}

v1100_about(){
  ui_text 'About iSH-AOK Config' "iSH-AOK Config $VERSION

v11 foundation milestone
- Central capability metadata
- Central software catalog
- Manifest-based module discovery
- RootFS-first builder dashboard
- Existing v10.12 workflows preserved

Project: https://github.com/emkey1/ish-AOK"
}

main_menu(){
  while :; do
    c=$(ui_menu "$PROGRAM $VERSION" "$(printf 'System: %s | %s | %s\nActive RootFS: %s' "${DISTRO_ID:-unknown}" "${ARCH:-unknown}" "${PKG_MGR:-unknown}" "$(active_rootfs 2>/dev/null || printf none)")" \
      builder 'RootFS Builder' rootfs 'Manage RootFS' system 'System Configuration' catalog 'Software Catalog' \
      plugins 'Modules & Plugins' health 'Health & Diagnostics' search 'Search' settings 'Settings' about 'About' exit 'Exit') || return 0
    case $c in
      builder) v1100_builder_dashboard;; rootfs) v104_manage_rootfs_menu;; system) v104_system_configuration_menu;;
      catalog) v1100_software_catalog_menu;; plugins) v1100_plugins_menu;; health) v112_diagnostics_menu;;
      search) v990_navigation_search_menu;; settings) v103_settings_menu;; about) v1100_about;; exit) return 0;;
    esac
  done
}
workspace_dashboard_v90(){ main_menu; }
workspace_dashboard_v91(){ main_menu; }
workspace_dashboard_v73(){ main_menu; }
