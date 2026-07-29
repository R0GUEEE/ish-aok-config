#!/bin/sh
# v11.3.0 main menu and compatibility hooks.

# Register successful staged builds after validation/export.
plugin_post_build_v113(){ v113_pipeline_register "$1"; }

main_menu(){
  while :; do
    _c=$(ui_menu "$PROGRAM $VERSION" "$(printf 'System: %s | %s | %s' "${DISTRO_ID:-unknown}" "${ARCH:-unknown}" "${PKG_MGR:-unknown}")" system 'System Configuration' rootfs 'Mini RootFS Builder' search Search settings Settings about About exit Exit) || return 0
    case $_c in system) v104_system_configuration_menu;; rootfs) v1160_rootfs_menu;; search) v990_navigation_search_menu;; settings) v103_settings_menu;; about) ui_text About "iSH-AOK Config $VERSION\n\nv11.3 system configuration, Mini RootFS builder, software catalog, settings, and navigation.\n\nProject: https://github.com/emkey1/ish-AOK";; exit) return 0;; esac
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
