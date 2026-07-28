#!/bin/sh

V88_BUILD_STATE=${V88_BUILD_STATE:-$STATE_DIR/build-v88}
V88_PLAN_DIR=${V88_PLAN_DIR:-$V88_BUILD_STATE/plans}
V88_RUN_DIR=${V88_RUN_DIR:-$V88_BUILD_STATE/runs}
V88_REPORT_DIR=${V88_REPORT_DIR:-$REPORT_DIR/build-v88}
mkdir -p "$V88_PLAN_DIR" "$V88_RUN_DIR" "$V88_REPORT_DIR" 2>/dev/null || true

v88_safe_token(){ case ${1:-} in ''|*[!A-Za-z0-9._:+@%/-]*) return 1;; *) return 0;; esac; }
v88_safe_packages(){ for p in $1; do v88_safe_token "$p" || return 1; done; }
v88_run_id(){ date '+%Y%m%d-%H%M%S' 2>/dev/null || printf '%s' "$$"; }
v88_current_run_file(){ printf '%s/current-run' "$V88_BUILD_STATE"; }
v88_current_run(){ cat "$(v88_current_run_file)" 2>/dev/null || true; }
v88_stage_state(){ run=$1; stage=$2; cat "$V88_RUN_DIR/$run/$stage.state" 2>/dev/null || printf pending; }
v88_mark_stage(){ run=$1; stage=$2; state=$3; mkdir -p "$V88_RUN_DIR/$run"; printf '%s\n' "$state" >"$V88_RUN_DIR/$run/$stage.state"; }

v88_backend_command(){
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)
  case $boot in
    debootstrap) printf debootstrap;; mmdebstrap) printf mmdebstrap;; apk) printf apk;;
    pacstrap) printf pacstrap;; dnf) command -v dnf >/dev/null 2>&1 && printf dnf || printf yum;;
    xbps) printf xbps-install;; stage3) printf tar;; build_fs) printf /opt/AOK/build_fs;;
    *) printf '%s' "$boot";;
  esac
}

v88_preflight_report(){
  v87_profile_defaults
  out=${1:-$V88_REPORT_DIR/preflight-$(v88_run_id).txt}
  mkdir -p "$(dirname "$out")"
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST)
  parent=$(dirname "$dest")
  backend=$(v88_backend_command)
  packages=$(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES)
  status=PASS
  {
    printf 'iSH-AOK Config 8.8.0 — Build Preflight\n\n'
    printf 'Profile: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME)"
    printf 'Target: %s %s %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO)" "$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)" "$(v87_profile_get "$V87_BUILD_PROFILE" ARCH)"
    printf 'Destination: %s\n' "$dest"
    printf 'Backend: %s\n\n' "$backend"
    if v87_profile_validate >/dev/null 2>&1; then printf '[PASS] profile validation\n'; else printf '[FAIL] profile validation\n'; status=FAIL; fi
    if v88_safe_packages "$packages"; then printf '[PASS] package-name validation\n'; else printf '[FAIL] unsafe package token\n'; status=FAIL; fi
    if [ "$backend" = /opt/AOK/build_fs ]; then [ -x "$backend" ] && printf '[PASS] backend available\n' || { printf '[FAIL] %s is unavailable\n' "$backend"; status=FAIL; }
    elif command -v "$backend" >/dev/null 2>&1; then printf '[PASS] backend available: %s\n' "$backend"; else printf '[FAIL] backend missing: %s\n' "$backend"; status=FAIL; fi
    if [ -d "$dest" ] && [ "$(find "$dest" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]; then printf '[WARN] destination is not empty\n'; else printf '[PASS] destination is empty or absent\n'; fi
    if [ -d "$parent" ] && [ -w "$parent" ]; then printf '[PASS] destination parent writable\n'; elif mkdir -p "$parent" 2>/dev/null; then printf '[PASS] destination parent created\n'; else printf '[FAIL] destination parent unavailable\n'; status=FAIL; fi
    case $(v87_profile_get "$V87_BUILD_PROFILE" ARCH) in
      arm64|aarch64) target=aarch64;; amd64|x86_64) target=x86_64;; *) target=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH);; esac
    host=$(uname -m 2>/dev/null || printf unknown)
    [ "$target" = "$host" ] && printf '[PASS] native architecture\n' || printf '[INFO] cross-architecture target: host=%s target=%s; second stage may require iSH-AOK execution support\n' "$host" "$target"
    printf '\nResult: %s\n' "$status"
  } >"$out"
  printf '%s\n' "$out"
  [ "$status" = PASS ]
}

v88_plan_generate(){
  v87_profile_defaults
  name=$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME); [ -n "$name" ] || name=default
  plan=${1:-$V88_PLAN_DIR/$name.plan.tsv}
  mkdir -p "$(dirname "$plan")"
  {
    printf 'preflight\tValidate profile, backend, packages and destination\talways\n'
    printf 'bootstrap\tCreate the base RootFS with %s\talways\n' "$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)"
    printf 'identity\tConfigure hostname, locale, timezone and resolver\talways\n'
    [ "$(v87_profile_get "$V87_BUILD_PROFILE" REGISTER_ROOTFS)" = yes ] && printf 'register\tRegister the completed RootFS\ton-success\n'
    [ "$(v87_profile_get "$V87_BUILD_PROFILE" CREATE_PROJECT)" = yes ] && printf 'project\tCreate a v8 RootFS project\ton-success\n'
    wf=$(v87_profile_get "$V87_BUILD_PROFILE" POST_WORKFLOW); [ -n "$wf" ] && [ "$wf" != none ] && printf 'workflow\tRun post-build workflow: %s\ton-success\n' "$wf"
  } >"$plan"
  printf '%s\n' "$plan"
}

v88_bootstrap(){
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); rel=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); mirror=$(v87_profile_get "$V87_BUILD_PROFILE" MIRROR)
  variant=$(v87_profile_get "$V87_BUILD_PROFILE" VARIANT); pkgs=$(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES)
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)
  mkdir -p "$dest"
  case $boot in
    debootstrap) set -- debootstrap --arch="$arch"; [ -n "$variant" ] && set -- "$@" --variant="$variant"; [ -n "$pkgs" ] && set -- "$@" --include="$(printf '%s' "$pkgs" | tr ' ' ',')"; set -- "$@" "$rel" "$dest"; [ -n "$mirror" ] && set -- "$@" "$mirror"; "$@";;
    mmdebstrap) set -- mmdebstrap --architectures="$arch"; [ -n "$variant" ] && set -- "$@" --variant="$variant"; set -- "$@" "$rel" "$dest"; [ -n "$mirror" ] && set -- "$@" "$mirror"; "$@";;
    apk) apk --root "$dest" --arch "$arch" --initdb add alpine-base $pkgs;;
    pacstrap) pacstrap -c "$dest" base $pkgs;;
    dnf) mgr=$(v88_backend_command); "$mgr" -y --installroot="$dest" --releasever="$rel" --forcearch="$arch" --setopt=install_weak_deps=False install $pkgs;;
    xbps) set -- xbps-install -Sy -r "$dest"; [ -n "$mirror" ] && set -- "$@" -R "$mirror"; "$@" base-system $pkgs;;
    build_fs) /opt/AOK/build_fs;;
    stage3) printf 'Stage3 execution requires an archive path; use Advanced builder tools.\n' >&2; return 2;;
    *) printf 'Unsupported bootstrap backend: %s\n' "$boot" >&2; return 2;;
  esac
}

v88_configure_identity(){
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST)
  host=$(v87_profile_get "$V87_BUILD_PROFILE" HOSTNAME); tz=$(v87_profile_get "$V87_BUILD_PROFILE" TIMEZONE); loc=$(v87_profile_get "$V87_BUILD_PROFILE" LOCALE)
  mkdir -p "$dest/etc"
  printf '%s\n' "$host" >"$dest/etc/hostname"
  [ -n "$tz" ] && printf '%s\n' "$tz" >"$dest/etc/timezone"
  [ -n "$loc" ] && { grep -q "^$loc" "$dest/etc/locale.gen" 2>/dev/null || printf '%s UTF-8\n' "$loc" >>"$dest/etc/locale.gen"; }
  if [ "$(v87_profile_get "$V87_BUILD_PROFILE" COPY_DNS)" = yes ] && [ -r /etc/resolv.conf ]; then cp /etc/resolv.conf "$dest/etc/resolv.conf"; fi
}

v88_run_stage(){
  run=$1; stage=$2
  logf="$V88_RUN_DIR/$run/build.log"
  v88_mark_stage "$run" "$stage" running
  printf '%s\tSTART\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$stage" >>"$logf"
  case $stage in
    preflight) v88_preflight_report "$V88_RUN_DIR/$run/preflight.txt" >/dev/null;;
    bootstrap) v88_bootstrap;;
    identity) v88_configure_identity;;
    register) command -v rootfs_register >/dev/null 2>&1 && rootfs_register "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)" || true;;
    project) command -v rootfs_project_create_from_path >/dev/null 2>&1 && rootfs_project_create_from_path "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)" || true;;
    workflow) wf=$(v87_profile_get "$V87_BUILD_PROFILE" POST_WORKFLOW); command -v workflow_run_named >/dev/null 2>&1 && workflow_run_named "$wf";;
  esac
  rc=$?
  if [ "$rc" -eq 0 ]; then v88_mark_stage "$run" "$stage" complete; printf '%s\tDONE\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$stage" >>"$logf"; else v88_mark_stage "$run" "$stage" failed; printf '%s\tFAIL(%s)\t%s\n' "$(date '+%F %T' 2>/dev/null)" "$rc" "$stage" >>"$logf"; fi
  return "$rc"
}

v88_execute_plan(){
  v87_profile_defaults; v87_profile_validate || return
  plan=$(v88_plan_generate)
  run=${1:-$(v88_run_id)}; mkdir -p "$V88_RUN_DIR/$run"; printf '%s\n' "$run" >"$(v88_current_run_file)"
  cp "$V87_BUILD_PROFILE" "$V88_RUN_DIR/$run/build.profile"; cp "$plan" "$V88_RUN_DIR/$run/plan.tsv"
  root=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); locked=no
  if command -v rootfs_lock_acquire >/dev/null 2>&1; then rootfs_lock_acquire "$root" build-v88 && locked=yes || return 1; fi
  rc=0
  while IFS="$(printf '\t')" read -r stage desc policy; do
    [ "$(v88_stage_state "$run" "$stage")" = complete ] && continue
    v88_run_stage "$run" "$stage" || { rc=$?; break; }
  done <"$plan"
  [ "$locked" = yes ] && rootfs_lock_release "$root" 2>/dev/null || true
  return "$rc"
}

v88_resume_current(){ run=$(v88_current_run); [ -n "$run" ] && [ -d "$V88_RUN_DIR/$run" ] || { ui_msg 'Build recovery' 'No resumable build run was found.'; return 1; }; v88_execute_plan "$run"; }
v88_run_report(){ run=${1:-$(v88_current_run)}; [ -n "$run" ] || return 1; { printf 'Build run: %s\n' "$run"; printf 'Profile: %s\n\n' "$V88_RUN_DIR/$run/build.profile"; while IFS="$(printf '\t')" read -r stage desc policy; do printf '%-12s %s\n' "$(v88_stage_state "$run" "$stage")" "$stage — $desc"; done <"$V88_RUN_DIR/$run/plan.tsv"; printf '\nLog: %s\n' "$V88_RUN_DIR/$run/build.log"; }; }
v88_cleanup_failed(){ run=$(v88_current_run); [ -n "$run" ] || return 1; dest=$(v87_profile_get "$V88_RUN_DIR/$run/build.profile" DEST); ui_yesno 'Clean failed build' "Remove incomplete destination?\n\n$dest\n\nRun records will be retained." || return; case $dest in /|/AOK|/root|/home|'') ui_msg Safety 'Refusing unsafe destination removal.'; return 1;; esac; rm -rf "$dest"; }

v88_build_execution_menu(){ while :; do c=$(ui_menu 'Build Execution and Recovery' 'Generate, inspect, execute and resume staged RootFS build plans.' preflight 'Run preflight checks' plan 'Generate and review build plan' execute 'Execute current profile as a staged build' resume 'Resume the current interrupted build' status 'View current build status' log 'View current build log' cleanup 'Clean incomplete destination safely') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in preflight) f=$(v88_preflight_report || true); ui_text 'Build preflight' "$(cat "$f" 2>/dev/null)";; plan) p=$(v88_plan_generate); ui_text 'Build plan' "$(cat "$p")";; execute) ui_yesno 'Execute build plan' 'This will create or modify the configured destination RootFS. Continue?' && v88_execute_plan;; resume) v88_resume_current;; status) ui_text 'Build status' "$(v88_run_report 2>/dev/null || printf 'No current run.')";; log) run=$(v88_current_run); ui_text 'Build log' "$(cat "$V88_RUN_DIR/$run/build.log" 2>/dev/null || printf 'No build log.')";; cleanup) v88_cleanup_failed;; esac; done; }

# Extend the canonical studio while retaining all v8.7 routes.
aok_builder_studio(){ while :; do c=$(ui_menu 'RootFS Build Studio' "Active RootFS: $(active_rootfs)" profile 'Guided build-profile configuration' execution 'Build execution and recovery' build 'Builder backends and RootFS import' recipes 'Reusable build recipes' queue 'Build queue and plans' projects 'RootFS projects' validate 'Compatibility and system preflight tools' artifacts 'Artifacts, archives and exports' overlays 'Overlay management' reports 'Build reports and logs') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in profile) v87_build_profile_wizard;; execution) v88_build_execution_menu;; build) aok_build_menu;; recipes) build_recipes_menu;; queue) aok_build_queue_menu;; projects) rootfs_projects_menu;; validate) aok_advanced_tools_menu;; artifacts) rootfs_import_export_studio;; overlays) overlay_studio_menu_v72 2>/dev/null || aok_more_options_menu;; reports) aok_build_logs;; esac; done; }

v88_build_plan_report(){ v87_profile_defaults; plan=$(v88_plan_generate); cat "$plan"; run=$(v88_current_run); [ -n "$run" ] && { printf '\nCurrent run:\n'; v88_run_report "$run"; } || true; }
