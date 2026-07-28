#!/bin/sh
# v11.1.0 pipeline UI and final RootFS Builder override.

v1110_pipeline_menu(){
  while :; do
    interrupted=$(v1110_interrupted_list 2>/dev/null | sed 's/|/ — /g')
    [ -n "$interrupted" ] || interrupted='No interrupted builds.'
    choice=$(ui_menu 'Build Pipeline' "$interrupted" \
      plan 'Preview the complete current build plan' \
      run 'Create a workspace and run the staged pipeline' \
      resume 'Resume the newest interrupted build' \
      history 'View persistent build history' \
      logs 'Open the newest build log' \
      back 'Back') || return 0
    case $choice in
      plan) ws=$(v1110_workspace_create preview-$(v1110_id)) && file=$(v1110_plan_report "$ws") && ui_text 'Build Plan' "$(cat "$file")";;
      run) ui_yesno 'Run staged build' 'Run the resumable v11.1 build pipeline now?' && { ws=$(v1110_workspace_create); if v1110_pipeline_run "$ws"; then ui_msg 'Build Pipeline' "Build completed.\n\n$ws"; else ui_msg 'Build Pipeline' "Build stopped and can be resumed.\n\n$ws"; fi; };;
      resume) ws=$(find "$V1110_BUILD_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1); [ -n "$ws" ] && v1110_pipeline_resume "$ws" || ui_msg 'Build Pipeline' 'No build workspace was found.';;
      history) ui_text 'Build History' "$(v1110_history_report)";;
      logs) ws=$(find "$V1110_BUILD_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1); [ -r "$ws/logs/builder.log" ] && ui_text 'Builder Log' "$(cat "$ws/logs/builder.log")" || ui_msg 'Builder Log' 'No builder log is available.';;
      back) return 0;;
    esac
  done
}

v1110_builder_dashboard(){
  v1101_init >/dev/null 2>&1 || true
  while :; do
    choice=$(ui_menu 'RootFS Builder' "Resumable pipeline | Backend: $(v1110_backend_name)\nTarget: $(v1101_profile_value DISTRO) $(v1101_profile_value RELEASE) / $(v1101_profile_value ARCH)" \
      pipeline 'Build Pipeline — plan, run, resume, history, and logs' \
      new 'Guided RootFS build configuration' \
      profiles 'Build profiles' \
      packages 'Reusable package sets' \
      queue 'Build queue' \
      repositories 'Builder repositories and mirrors' \
      keyrings 'Target-distribution keyring cache' \
      cache 'Download and artifact cache' \
      validate 'Pre-build validation' \
      artifacts 'Artifacts and manifests' \
      manage 'Manage existing RootFS filesystems' \
      advanced 'Advanced builder tools' \
      back 'Back') || return 0
    case $choice in
      pipeline) v1110_pipeline_menu;; new) v102_guided_build;; profiles) v1101_profile_menu;; packages) v1101_package_sets_menu;;
      queue) v1101_queue_menu;; repositories) v1101_builder_repositories_menu;; keyrings) v110_rootfs_keyrings_menu;; cache) v1101_cache_menu;;
      validate) v1101_validation_menu;; artifacts) v1101_artifacts_menu;; manage) v104_manage_rootfs_menu;; advanced) v102_advanced_build_menu;; back) return 0;;
    esac
  done
}
v1100_builder_dashboard(){ v1110_builder_dashboard; }
v1101_builder_dashboard(){ v1110_builder_dashboard; }
