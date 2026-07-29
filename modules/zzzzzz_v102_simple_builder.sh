#!/bin/sh
# v10.2 Simplified RootFS builder interface.

v102_profile_value(){
  v87_profile_get "$V87_BUILD_PROFILE" "$1"
}

v102_build_summary(){
  v93_profile_defaults_extend
  printf '%s %s — RootFS Build Summary\n\n' "$PROGRAM" "$VERSION"
  printf 'Distribution: %s %s\n' "$(v102_profile_value DISTRO)" "$(v102_profile_value RELEASE)"
  printf 'Architecture: %s\n' "$(v102_profile_value ARCH)"
  printf 'Source:       %s' "$(v102_profile_value SOURCE_TYPE)"
  _v102_source=$(v102_profile_value SOURCE_VALUE)
  [ -n "$_v102_source" ] && printf ' — %s' "$_v102_source"
  printf '\n'
  printf 'Destination:  %s\n' "$(v102_profile_value DEST)"
  printf 'Builder:      %s\n' "$(v102_profile_value BOOTSTRAP)"
  printf 'Init:         %s\n' "$(v102_profile_value INIT)"
  printf 'Shell:        %s\n' "$(v102_profile_value SHELL_PATH)"
  printf 'Packages:     %s\n' "$(v102_profile_value PACKAGES)"
  printf 'Archive:      %s' "$(v102_profile_value CREATE_ARCHIVE)"
  [ "$(v102_profile_value CREATE_ARCHIVE)" = yes ] && printf ' — %s in %s' "$(v102_profile_value COMPRESSION)" "$(v102_profile_value ARTIFACT_DIR)"
  printf '\n'
}

v102_step(){
  "$@"
  _v102_rc=$?
  [ "$_v102_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return "${UI_MENU_BACK_RC:-90}"
  return "$_v102_rc"
}

v102_guided_build(){
  v93_profile_defaults_extend
  ui_msg 'Guided RootFS Build' 'This wizard asks only for the target, source, destination, packages and final build confirmation.'

  v102_step v87_profile_choose_distro || return $?
  v102_step v87_profile_choose_arch || return $?
  v102_step v93_profile_source_select || return $?
  v102_step v92_profile_location_select || return $?
  v102_step v87_profile_choose_packages || return $?

  if ui_yesno 'Optional configuration' 'Configure hostname, user, init system, shell and post-build features?'; then
    v102_step v92_profile_choose_identity || return $?
    v102_step v87_profile_choose_init_shell || return $?
    v102_step v87_profile_choose_options || return $?
  fi

  ui_text 'Build summary' "$(v102_build_summary)"
  v87_profile_validate || return 1
  ui_yesno 'Start RootFS build' 'Validation passed. Generate and execute the staged build now?' || return 0
  v88_execute_plan
}

v102_current_build_menu(){
  while :; do
    _v102_choice=$(ui_menu 'Current RootFS Build' "$(v102_build_summary)" \
      review 'Review current build settings' \
      target 'Change distribution and architecture' \
      paths 'Change source and RootFS destination' \
      packages 'Change package groups' \
      options 'Change optional system settings' \
      validate 'Validate and run preflight checks' \
      execute 'Execute, resume, status and logs' \
      reset 'Reset build settings to defaults' \
      back 'Back') || {
        _v102_rc=$?
        [ "$_v102_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0
        return "$_v102_rc"
      }
    case $_v102_choice in
      review) ui_text 'Build summary' "$(v102_build_summary)";;
      target) v102_step v87_profile_choose_distro && v102_step v87_profile_choose_arch;;
      paths) v102_step v93_profile_source_select && v102_step v92_profile_location_select;;
      packages) v102_step v87_profile_choose_packages;;
      options)
        v102_step v92_profile_choose_identity &&
        v102_step v87_profile_choose_init_shell &&
        v102_step v87_profile_choose_options &&
        v102_step v93_profile_artifact_select
        ;;
      validate)
        v87_profile_validate
        _v102_preflight=$(v88_preflight_report 2>/dev/null || true)
        [ -n "$_v102_preflight" ] && ui_text 'Build preflight' "$(cat "$_v102_preflight" 2>/dev/null)"
        ;;
      execute) v88_build_execution_menu;;
      reset)
        ui_yesno 'Reset build settings' 'Replace the current build profile with recommended defaults?' && {
          rm -f "$V87_BUILD_PROFILE"
          v93_profile_defaults_extend
        }
        ;;
      back) return 0;;
    esac
  done
}

v102_advanced_build_menu(){
  while :; do
    _v102_choice=$(ui_menu 'Advanced RootFS Builder' 'Optional tools for multiple builds, direct backends and recovery.' \
      matrix 'Build matrices, recipes and queue' \
      backends 'Direct builder backends and imports' \
      capabilities 'Builder capability detection' \
      recovery 'Build recovery, history and detailed logs' \
      back 'Back') || {
        _v102_rc=$?
        [ "$_v102_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0
        return "$_v102_rc"
      }
    case $_v102_choice in
      matrix) v94_matrix_studio;;
      backends) v87_manual_builders_menu;;
      capabilities) v95_builder_capabilities_ui;;
      recovery) v88_build_execution_menu;;
      back) return 0;;
    esac
  done
}

# Compatibility entry points now open the simplified builder.
unified_build_menu(){ v91_menu_run build; }
v90_build_workflow_menu(){ v91_menu_run build; }
aok_builder_studio(){ v91_menu_run build; }
