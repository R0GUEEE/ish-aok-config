#!/bin/sh
# v9.3 Build Source & Artifact Integration

v93_profile_defaults_extend(){
  v87_profile_defaults
  [ -n "$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE)" ] || v87_profile_set "$V87_BUILD_PROFILE" SOURCE_TYPE repository
  [ -n "$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_VALUE)" ] || v87_profile_set "$V87_BUILD_PROFILE" SOURCE_VALUE "$(v87_profile_get "$V87_BUILD_PROFILE" MIRROR)"
  [ -n "$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR)" ] || v87_profile_set "$V87_BUILD_PROFILE" ARTIFACT_DIR "$(v93_artifact_default)"
  [ -n "$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_ARCHIVE)" ] || v87_profile_set "$V87_BUILD_PROFILE" CREATE_ARCHIVE no
}

v93_profile_source_select(){
  v93_profile_defaults_extend
  t=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE); v=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_VALUE)
  out=$(v93_source_select "$t" "$v") || return
  nt=${out%%|*}; nv=${out#*|}
  v87_profile_set "$V87_BUILD_PROFILE" SOURCE_TYPE "$nt"
  v87_profile_set "$V87_BUILD_PROFILE" SOURCE_VALUE "$nv"
  [ "$nt" = repository ] && v87_profile_set "$V87_BUILD_PROFILE" MIRROR "$nv"
  ui_msg 'Build source' "Source type: $nt\nSource: ${nv:-backend default}"
}

v93_profile_artifact_select(){
  v93_profile_defaults_extend
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR)
  p=$(v93_artifact_select "$cur") || return
  v87_profile_set "$V87_BUILD_PROFILE" ARTIFACT_DIR "$p"
  cur=$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_ARCHIVE)
  c=$(ui_radiolist 'Build artifact' 'Create a compressed RootFS archive after a successful build?' yes 'Create archive' "$(v87_choice_state "$cur" yes)" no 'Do not create archive automatically' "$(v87_choice_state "$cur" no)") || return
  v87_profile_set "$V87_BUILD_PROFILE" CREATE_ARCHIVE "$c"
}

v87_profile_validate(){
  v93_profile_defaults_extend; errors=''
  for k in DISTRO RELEASE ARCH DEST BOOTSTRAP INIT SHELL_PATH SOURCE_TYPE ARTIFACT_DIR; do v=$(v87_profile_get "$V87_BUILD_PROFILE" "$k"); [ -n "$v" ] || errors="$errors\nMissing: $k"; done
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); msg=$(rootfs_location_validate "$dest" 2>&1) || errors="$errors\n$msg"
  st=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE); sv=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_VALUE); msg=$(v93_source_validate "$st" "$sv" 2>&1) || errors="$errors\n$msg"
  art=$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR); msg=$(v93_artifact_validate "$art" 2>&1) || errors="$errors\n$msg"
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); case $arch in arm64|aarch64|i386|amd64|x86_64|riscv64) :;; *) errors="$errors\nUnsupported ARCH: $arch";; esac
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP); case $boot in debootstrap|mmdebstrap|apk|pacstrap|dnf|xbps|stage3|build_fs) :;; *) errors="$errors\nUnknown BOOTSTRAP: $boot";; esac
  [ -z "$errors" ] || { ui_msg 'Build profile validation' "Validation failed:$errors"; return 1; }
  ui_msg 'Build profile validation' 'Profile is valid.'
}

v87_build_profile_wizard(){
  v93_profile_defaults_extend
  while :; do
    c=$(ui_menu 'Build Profile Wizard' "Destination: $(v87_profile_get "$V87_BUILD_PROFILE" DEST)\nSource: $(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE)\nArtifacts: $(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR)" distro 'Distribution preset' arch 'Architecture' source 'Build source and mirror' location 'RootFS destination location' artifacts 'Artifact output and archive policy' bootstrap 'Bootstrap backend' packages 'Package groups' features 'Build features' identity 'Identity and release' init 'Init system and default shell' compression 'Archive compression' summary 'Review profile summary' validate 'Validate profile' reset 'Reset to recommended defaults') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in distro) v87_profile_choose_distro;; arch) v87_profile_choose_arch;; source) v93_profile_source_select;; location) v92_profile_location_select;; artifacts) v93_profile_artifact_select;; bootstrap) v87_profile_choose_bootstrap;; packages) v87_profile_choose_packages;; features) v87_profile_choose_options;; identity) v92_profile_choose_identity;; init) v87_profile_choose_init_shell;; compression) v87_profile_choose_compression;; summary) v87_profile_summary;; validate) v87_profile_validate;; reset) ui_yesno Reset 'Replace the current profile with recommended defaults?' && { rm -f "$V87_BUILD_PROFILE"; v93_profile_defaults_extend; };; esac
  done
}

v93_fetch_archive(){
  src=$1; out=$2
  case $src in
    file://*) cp "${src#file://}" "$out";;
    http://*|https://*|ftp://*)
      if have curl; then curl -fL "$src" -o "$out"
      elif have wget; then wget -O "$out" "$src"
      else printf 'curl or wget is required for remote archives.\n' >&2; return 1
      fi;;
    /*) cp "$src" "$out";;
    *) return 1;;
  esac
}

v93_extract_archive(){
  archive=$1; dest=$2; mkdir -p "$dest"
  case $archive in
    *.tar.gz|*.tgz) tar -xzf "$archive" -C "$dest";;
    *.tar.xz|*.txz) tar -xJf "$archive" -C "$dest";;
    *.tar.zst|*.tzst) have zstd || { printf 'zstd is required for this archive.\n' >&2; return 1; }; zstd -dc "$archive" | tar -xf - -C "$dest";;
    *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dest";;
    *.tar) tar -xf "$archive" -C "$dest";;
    *) printf 'Unsupported archive format: %s\n' "$archive" >&2; return 2;;
  esac
}

v88_bootstrap(){
  v93_profile_defaults_extend
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); rel=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); mirror=$(v87_profile_get "$V87_BUILD_PROFILE" MIRROR)
  variant=$(v87_profile_get "$V87_BUILD_PROFILE" VARIANT); pkgs=$(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES)
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP); st=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE); sv=$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_VALUE)
  case $st in
    archive)
      tmp="$TMP_DIR/build-source.$$.archive"; v93_fetch_archive "$sv" "$tmp" && v93_extract_archive "$tmp" "$dest"; return $?;;
    directory)
      [ -d "$sv" ] || { printf 'Source directory not found: %s\n' "$sv" >&2; return 1; }
      mkdir -p "$dest" || return 1
      if have rsync; then rsync -aH "$sv/" "$dest/"; else cp -a "$sv/." "$dest/"; fi
      return $?;;
    repository) [ -n "$sv" ] && mirror=$sv;;
    native) mirror='';;
  esac
  mkdir -p "$dest"
  case $boot in
    debootstrap) set -- debootstrap --arch="$arch"; [ -n "$variant" ] && set -- "$@" --variant="$variant"; [ -n "$pkgs" ] && set -- "$@" --include="$(printf '%s' "$pkgs" | tr ' ' ',')"; set -- "$@" "$rel" "$dest"; [ -n "$mirror" ] && set -- "$@" "$mirror"; "$@";;
    mmdebstrap) set -- mmdebstrap --architectures="$arch"; [ -n "$variant" ] && set -- "$@" --variant="$variant"; set -- "$@" "$rel" "$dest"; [ -n "$mirror" ] && set -- "$@" "$mirror"; "$@";;
    apk) [ -n "$mirror" ] && { mkdir -p "$dest/etc/apk"; printf '%s/%s/main\n' "${mirror%/}" "$rel" >"$dest/etc/apk/repositories"; }; apk --root "$dest" --arch "$arch" --initdb add alpine-base $pkgs;;
    pacstrap) pacstrap -c "$dest" base $pkgs;;
    dnf) mgr=$(v88_backend_command); "$mgr" -y --installroot="$dest" --releasever="$rel" --forcearch="$arch" --setopt=install_weak_deps=False install $pkgs;;
    xbps) set -- xbps-install -Sy -r "$dest"; [ -n "$mirror" ] && set -- "$@" -R "$mirror"; "$@" base-system $pkgs;;
    build_fs) /opt/AOK/build_fs;;
    stage3) printf 'Set SOURCE_TYPE=archive and choose a stage3 archive.\n' >&2; return 2;;
    *) printf 'Unsupported bootstrap backend: %s\n' "$boot" >&2; return 2;;
  esac
}

v88_plan_generate(){
  v93_profile_defaults_extend
  name=$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME); [ -n "$name" ] || name=default
  plan=${1:-$V88_PLAN_DIR/$name.plan.tsv}; mkdir -p "$(dirname "$plan")"
  {
    printf 'preflight\tValidate profile, source, backend, packages and paths\talways\n'
    printf 'bootstrap\tCreate the base RootFS with %s\talways\n' "$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)"
    printf 'identity\tConfigure hostname, locale, timezone and resolver\talways\n'
    [ "$(v87_profile_get "$V87_BUILD_PROFILE" REGISTER_ROOTFS)" = yes ] && printf 'register\tRegister the completed RootFS\ton-success\n'
    [ "$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_PROJECT)" = yes ] && printf 'project\tCreate a v8 RootFS project\ton-success\n'
    [ "$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_ARCHIVE)" = yes ] && printf 'artifact\tCreate a compressed RootFS artifact\ton-success\n'
    wf=$(v87_profile_get "$V87_BUILD_PROFILE" POST_WORKFLOW); [ -n "$wf" ] && [ "$wf" != none ] && printf 'workflow\tRun post-build workflow: %s\ton-success\n' "$wf"
  } >"$plan"; printf '%s\n' "$plan"
}

v93_create_artifact(){
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); out=$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR); comp=$(v87_profile_get "$V87_BUILD_PROFILE" COMPRESSION)
  [ -d "$dest" ] || return 1; mkdir -p "$out" || return 1
  base=$(basename "$dest"); parent=$(dirname "$dest")
  case $comp in zstd) file="$out/$base.tar.zst"; tar -C "$parent" -cf - "$base" | zstd -T0 -q -o "$file";; gzip) file="$out/$base.tar.gz"; tar -C "$parent" -czf "$file" "$base";; xz) file="$out/$base.tar.xz"; tar -C "$parent" -cJf "$file" "$base";; none|'') file="$out/$base.tar"; tar -C "$parent" -cf "$file" "$base";; *) return 2;; esac
  printf '%s\n' "$file" >"$V88_RUN_DIR/$(v88_current_run)/artifact.path" 2>/dev/null || true
}

v88_run_stage(){
  run=$1; stage=$2; logf="$V88_RUN_DIR/$run/build.log"; v88_mark_stage "$run" "$stage" running; printf '%s\tSTART\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$stage" >>"$logf"
  case $stage in preflight) v88_preflight_report "$V88_RUN_DIR/$run/preflight.txt" >/dev/null;; bootstrap) v88_bootstrap;; identity) v88_configure_identity;; register) command -v rootfs_register >/dev/null 2>&1 && rootfs_register "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)" || true;; project) command -v rootfs_project_create_from_path >/dev/null 2>&1 && rootfs_project_create_from_path "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)" || true;; artifact) v93_create_artifact;; workflow) wf=$(v87_profile_get "$V87_BUILD_PROFILE" POST_WORKFLOW); command -v workflow_run_named >/dev/null 2>&1 && workflow_run_named "$wf";; esac
  rc=$?; if [ "$rc" -eq 0 ]; then v88_mark_stage "$run" "$stage" complete; printf '%s\tDONE\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$stage" >>"$logf"; else v88_mark_stage "$run" "$stage" failed; printf '%s\tFAIL(%s)\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$rc" "$stage" >>"$logf"; fi; return "$rc"
}

v93_paths_menu(){
  while :; do c=$(ui_menu 'Build Sources and Artifacts' 'Configure all build input and output paths in one place.' source 'Select build source or mirror' rootfs 'Select RootFS destination' artifact 'Select artifact output and archive policy' summary 'Review complete build path summary' recent_sources 'Recent build sources' recent_artifacts 'Recent artifact directories') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in source) v93_profile_source_select;; rootfs) v92_profile_location_select;; artifact) v93_profile_artifact_select;; summary) ui_text 'Build path summary' "$(v93_build_paths_report)";; recent_sources) ui_text 'Recent build sources' "$(v93_recent_values "$V93_RECENT_SOURCES")";; recent_artifacts) ui_text 'Recent artifact directories' "$(v93_recent_values "$V93_RECENT_ARTIFACTS")";; esac; done
}

aok_builder_studio(){
  v93_profile_defaults_extend
  while :; do c=$(ui_menu 'RootFS Build Studio' "Source: $(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE) | Destination: $(v87_profile_get "$V87_BUILD_PROFILE" DEST)" profiles 'Build profiles and presets' paths 'Build sources, destinations and artifacts' execution 'Build execution, resume and recovery' recipes 'Build recipes and queue' projects 'RootFS projects' backends 'Builder backends and RootFS import' validate 'Compatibility and preflight tools' artifacts 'Artifacts, archives and exports' overlays 'Overlay management' reports 'Build reports and logs') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in profiles) v89_profile_manager_menu;; paths) v93_paths_menu;; execution) v88_build_execution_menu;; recipes) v89_recipes_queue_menu;; projects) rootfs_projects_menu;; backends) v87_manual_builders_menu;; validate) aok_advanced_tools_menu;; artifacts) rootfs_import_export_studio;; overlays) overlay_studio_menu_v72 2>/dev/null || aok_more_options_menu;; reports) aok_build_logs;; esac; done
}

v93_build_paths_report_cli(){ v93_profile_defaults_extend; v93_build_paths_report; }
