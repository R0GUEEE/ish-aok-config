#!/bin/sh
# v11.0.1 RootFS Builder framework and dashboard.

v1101_profile_menu(){
  while :; do
    set --
    while IFS='|' read -r id label sets file; do
      [ -n "$id" ] || continue
      marker=''
      [ "${V89_ACTIVE_PROFILE:-standard}" = "$id" ] && marker=' [active]'
      set -- "$@" "$id" "$label — package sets: $sets$marker"
    done <<EOF_LIST
$(v1101_profile_list)
EOF_LIST
    set -- "$@" custom 'Use the legacy guided profile editor' back 'Back'
    choice=$(ui_menu 'Build Profiles' 'Choose a reusable v11 build profile. Applying a profile updates the active package manifest without changing the target distribution or destination.' "$@") || return 0
    case $choice in
      back) return 0;;
      custom) v89_profile_manager_menu;;
      *)
        packages=$(v1101_apply_profile "$choice") || { ui_msg 'Build Profiles' "Unable to apply profile: $choice"; continue; }
        ui_text 'Profile applied' "Profile: $choice\nPackage sets: $(v1101_profile_value PACKAGE_SETS)\n\nResolved packages:\n$packages"
        ;;
    esac
  done
}

v1101_package_sets_menu(){
  while :; do
    args=''
    set --
    while IFS='|' read -r id label desc file; do
      [ -n "$id" ] || continue
      set -- "$@" "$id" "$label — $desc" off
    done <<EOF_LIST
$(v1101_package_set_list)
EOF_LIST
    selected=$(ui_checklist 'Package Sets' 'Space toggles package sets. Selected sets are merged, dependencies are expanded, and duplicate native packages are removed.' "$@") || return 0
    [ -n "$selected" ] || return 0
    sets=$(printf '%s\n' "$selected" | tr '\n' ' ' | sed 's/ $//')
    distro=$(v1101_profile_value DISTRO); [ -n "$distro" ] || distro=${V102_DISTRO:-unknown}
    packages=$(v1101_packages_for_sets "$sets" "$distro")
    ui_text 'Package Set Preview' "Target distribution: $distro\nSelected sets: $sets\n\nResolved packages:\n$packages"
    if ui_yesno 'Apply package sets' 'Replace the active build package manifest with this merged selection?'; then
      v87_profile_defaults >/dev/null 2>&1 || true
      v87_profile_set "$V87_BUILD_PROFILE" PACKAGE_SETS "$sets"
      v87_profile_set "$V87_BUILD_PROFILE" PACKAGES "$packages"
      ui_msg 'Package Sets' 'The active build package manifest was updated.'
    fi
  done
}


v1101_builder_repositories_menu(){
  while :; do
    distro=$(v1101_profile_value DISTRO); release=$(v1101_profile_value RELEASE)
    mirror=$(v1101_profile_value MIRROR); [ -n "$mirror" ] || mirror='distribution default'
    choice=$(ui_menu 'Builder Repositories' "These settings apply only to the RootFS build profile.\nTarget: $distro $release\nMirror: $mirror" \
      mirror 'Set the primary bootstrap mirror' \
      preview 'Preview current target repository settings' \
      keyrings 'Manage target archive keys' \
      legacy 'Open advanced builder source and backend selection' \
      back 'Back') || return 0
    case $choice in
      mirror)
        value=$(ui_input 'Builder Mirror' 'Official bootstrap mirror URL. Leave empty to use the distribution default.' "$(v1101_profile_value MIRROR)") || continue
        v87_profile_set "$V87_BUILD_PROFILE" MIRROR "$value"
        ;;
      preview)
        ui_text 'Builder Repository Preview' "Distribution: $distro\nRelease: $release\nMirror: $(v1101_profile_value MIRROR)\nBootstrap: $(v1101_profile_value BOOTSTRAP)\nKeyring: $(v1101_keyring_for_target "$distro" 2>/dev/null || printf 'backend-native')"
        ;;
      keyrings) v110_rootfs_keyrings_menu;;
      legacy) v102_current_build_menu;;
      back) return 0;;
    esac
  done
}

v1101_cache_menu(){
  while :; do
    choice=$(ui_menu 'Builder Cache' "$(v1101_cache_report)" \
      keyrings 'Open target-distribution keyring cache manager' \
      report 'Refresh cache inventory' \
      purge_metadata 'Purge cached metadata and mirror results' \
      purge_packages 'Purge cached package downloads' \
      purge_artifacts 'Purge cached build artifacts' \
      back 'Back') || return 0
    case $choice in
      keyrings) v110_rootfs_keyrings_menu;;
      report) ui_text 'Builder Cache' "$(v1101_cache_report)";;
      purge_metadata) ui_yesno 'Purge builder metadata' 'Remove cached metadata, mirror results, and bootstrap indexes?' && { rm -rf "$V1101_CACHE_METADATA"/* "$V1101_CACHE_MIRRORS"/* "$V1101_CACHE_BOOTSTRAP"/* 2>/dev/null || run_root sh -c "rm -rf '$V1101_CACHE_METADATA'/* '$V1101_CACHE_MIRRORS'/* '$V1101_CACHE_BOOTSTRAP'/*"; };;
      purge_packages) ui_yesno 'Purge package cache' 'Remove package downloads cached by the RootFS Builder?' && { rm -rf "$V1101_CACHE_PACKAGES"/* 2>/dev/null || run_root sh -c "rm -rf '$V1101_CACHE_PACKAGES'/*"; };;
      purge_artifacts) ui_yesno 'Purge artifact cache' 'Remove artifacts stored in the shared builder cache?' && { rm -rf "$V1101_CACHE_ARTIFACTS"/* 2>/dev/null || run_root sh -c "rm -rf '$V1101_CACHE_ARTIFACTS'/*"; };;
      back) return 0;;
    esac
  done
}

v1101_validation_menu(){
  report=$(v1101_validation_report 2>/dev/null); rc=$?
  [ -n "$report" ] || { ui_msg 'Builder Validation' 'The validation report could not be generated.'; return 1; }
  ui_text 'Builder Validation' "$(cat "$report" 2>/dev/null)"
  return "$rc"
}

v1101_queue_menu(){
  while :; do
    choice=$(ui_menu 'Build Queue' "$(v1101_queue_report)" \
      add 'Add the current build profile to the queue' \
      list 'Refresh queue report' \
      run 'Run the next queued build' \
      clear 'Remove all queued jobs' \
      legacy 'Open legacy build recipes and queue' \
      back 'Back') || return 0
    case $choice in
      add)
        job=$(v1101_queue_add) && ui_msg 'Build Queue' "Queued: $job"
        ;;
      list) ui_text 'Build Queue' "$(v1101_queue_report)";;
      run)
        job=$(find "$V1101_QUEUE_DIR" -maxdepth 1 -type f -name '*.job' 2>/dev/null | sort | head -n 1)
        [ -n "$job" ] || { ui_msg 'Build Queue' 'The queue is empty.'; continue; }
        ui_yesno 'Run queued build' "Load and execute this job?\n\n$job" || continue
        cp "$job" "$V87_BUILD_PROFILE" || { ui_msg 'Build Queue' 'Could not activate the queued profile.'; continue; }
        sed -i 's/^STATUS=.*/STATUS=running/' "$job" 2>/dev/null || true
        if v1101_execute_current_build; then
          sed -i 's/^STATUS=.*/STATUS=complete/' "$job" 2>/dev/null || true
          mv "$job" "$job.complete" 2>/dev/null || true
        else
          sed -i 's/^STATUS=.*/STATUS=failed/' "$job" 2>/dev/null || true
        fi
        ;;
      clear) ui_yesno 'Clear Build Queue' 'Remove all queued and completed job metadata?' && rm -f "$V1101_QUEUE_DIR"/*.job "$V1101_QUEUE_DIR"/*.job.complete 2>/dev/null;;
      legacy) v89_recipes_queue_menu;;
      back) return 0;;
    esac
  done
}

v1101_artifacts_menu(){
  while :; do
    choice=$(ui_menu 'Build Artifacts' "$(v1101_artifact_report)" \
      report 'Refresh artifact inventory' \
      manifest 'Generate a manifest for the current build profile' \
      latest 'Open the latest generated manifest' \
      legacy 'Open import, export, compression, and artifact tools' \
      back 'Back') || return 0
    case $choice in
      report) ui_text 'Build Artifacts' "$(v1101_artifact_report)";;
      manifest) file=$(v1101_manifest_generate) && ui_text 'Build Manifest' "$(cat "$file")";;
      latest)
        file=$(find "$V1101_MANIFEST_DIR" -type f -name '*.manifest' 2>/dev/null | sort | tail -n 1)
        [ -n "$file" ] && ui_text 'Latest Build Manifest' "$(cat "$file")" || ui_msg 'Build Manifest' 'No manifests have been generated.'
        ;;
      legacy) rootfs_import_export_studio;;
      back) return 0;;
    esac
  done
}

v1101_post_build_validate(){
  dest=$(v1101_profile_value DEST)
  report=$V1101_REPORT_DIR/post-build-$(date +%Y%m%d-%H%M%S 2>/dev/null || printf now).txt
  pass=0 fail=0 warn=0
  {
    printf '%s %s — Post-build RootFS Validation\n\n' "$PROGRAM" "$VERSION"
    printf 'RootFS: %s\n\n' "$dest"
    if [ -d "$dest" ]; then printf '[PASS] RootFS destination exists\n'; pass=$((pass+1)); else printf '[FAIL] RootFS destination is missing\n'; fail=$((fail+1)); fi
    for path in etc usr var tmp; do
      if [ -d "$dest/$path" ]; then printf '[PASS] /%s exists\n' "$path"; pass=$((pass+1)); else printf '[FAIL] /%s missing\n' "$path"; fail=$((fail+1)); fi
    done
    if [ -r "$dest/etc/os-release" ]; then printf '[PASS] /etc/os-release present\n'; pass=$((pass+1)); else printf '[WARN] /etc/os-release missing\n'; warn=$((warn+1)); fi
    if [ -r "$dest/etc/resolv.conf" ] || [ -L "$dest/etc/resolv.conf" ]; then printf '[PASS] DNS configuration present\n'; pass=$((pass+1)); else printf '[WARN] DNS configuration missing\n'; warn=$((warn+1)); fi
    if [ -x "$dest/bin/sh" ] || [ -x "$dest/usr/bin/sh" ]; then printf '[PASS] shell executable present\n'; pass=$((pass+1)); else printf '[FAIL] shell executable missing\n'; fail=$((fail+1)); fi
    if [ -d "$dest/etc/apt" ]; then
      find "$dest/usr/share/keyrings" "$dest/etc/apt/keyrings" -type f 2>/dev/null | grep -q . && { printf '[PASS] APT keyring files present\n'; pass=$((pass+1)); } || { printf '[WARN] no APT keyring files detected\n'; warn=$((warn+1)); }
    fi
    printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$pass" "$warn" "$fail"
  } >"$report"
  V1101_LAST_POST_VALIDATION=$report; export V1101_LAST_POST_VALIDATION
  printf '%s\n' "$report"
  [ "$fail" -eq 0 ]
}

v1101_execute_current_build(){
  preflight=$(v1101_validation_report 2>/dev/null); rc=$?
  [ -n "$preflight" ] && ui_text 'Build Preflight' "$(cat "$preflight")"
  [ "$rc" -eq 0 ] || { ui_msg 'Build blocked' 'Preflight found one or more release-blocking failures.'; return 1; }
  ui_yesno 'Execute RootFS build' 'Validation passed. Create or modify the configured RootFS destination now?' || return 0
  if v88_execute_plan; then
    post=$(v1101_post_build_validate 2>/dev/null || true)
    manifest=$(v1101_manifest_generate 2>/dev/null || true)
    ui_text 'Build Complete' "Post-build report: $post\nManifest: $manifest\n\n$(cat "$post" 2>/dev/null)"
    return 0
  fi
  ui_msg 'Build failed' 'The staged build did not complete. Use Build Queue or Advanced Builder Tools to inspect status and logs.'
  return 1
}

v1101_builder_dashboard(){
  v1101_init >/dev/null 2>&1 || true
  while :; do
    profile=${V89_ACTIVE_PROFILE:-standard}
    distro=$(v1101_profile_value DISTRO); [ -n "$distro" ] || distro=${V102_DISTRO:-not_selected}
    arch=$(v1101_profile_value ARCH); [ -n "$arch" ] || arch=${V102_ARCH:-not_selected}
    choice=$(ui_menu 'RootFS Builder' "Target: $distro | Architecture: $arch\nProfile: $profile | Package sets: $(v1101_profile_value PACKAGE_SETS)" \
      new 'Build New RootFS — guided target, source, destination, and options' \
      profiles 'Build Profiles — Minimal, Standard, Developer, Server, Container, Recovery' \
      packages 'Package Sets — reusable distribution-aware manifests' \
      queue 'Build Queue — save and run build jobs' \
      repositories 'Builder repositories, mirrors, and source configuration' \
      keyrings 'Target-distribution keyring cache' \
      cache 'Download and artifact cache' \
      validate 'Pre-build validation and readiness report' \
      execute 'Validate and build the current RootFS plan' \
      artifacts 'Build artifacts and reproducibility manifests' \
      manage 'Import, export, clone, repair, and inspect RootFS filesystems' \
      advanced 'Advanced builder backends, paths, logs, and recovery' \
      back 'Back') || return 0
    case $choice in
      new) v102_guided_build;;
      profiles) v1101_profile_menu;;
      packages) v1101_package_sets_menu;;
      queue) v1101_queue_menu;;
      repositories) v1101_builder_repositories_menu;;
      keyrings) v110_rootfs_keyrings_menu;;
      cache) v1101_cache_menu;;
      validate) v1101_validation_menu;;
      execute) v1101_execute_current_build;;
      artifacts) v1101_artifacts_menu;;
      manage) v104_manage_rootfs_menu;;
      advanced) v102_advanced_build_menu;;
      back) return 0;;
    esac
  done
}

# Latest implementation wins because modules are sourced alphabetically.
v1100_builder_dashboard(){ v1101_builder_dashboard; }
