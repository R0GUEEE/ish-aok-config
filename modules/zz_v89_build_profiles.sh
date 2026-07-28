#!/bin/sh

V89_PRESET_DIR=${V89_PRESET_DIR:-$STATE_DIR/build-v89/presets}
V89_PROFILE_LIBRARY=${V89_PROFILE_LIBRARY:-$STATE_DIR/build-v89/profiles}
mkdir -p "$V89_PRESET_DIR" "$V89_PROFILE_LIBRARY" 2>/dev/null || true

v89_safe_id(){ printf '%s' "$1" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9._-'; }
v89_profile_name(){ v87_profile_get "$1" PROFILE_NAME; }
v89_profile_copy(){ src=$1; dst=$2; [ -f "$src" ] || return 1; mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"; }

v89_preset_write(){
  id=$1; distro=$2; release=$3; arch=$4; bootstrap=$5; init=$6; packages=$7
  file="$V89_PRESET_DIR/$id.profile"
  cat >"$file" <<EOF_PROFILE
PROFILE_NAME=$id
DISTRO=$distro
RELEASE=$release
ARCH=$arch
DEST=/AOK/roots/${distro}-${release}-${arch}
MIRROR=
BOOTSTRAP=$bootstrap
VARIANT=minbase
PACKAGES=$packages
INIT=$init
HOSTNAME=ish-aok
USER_NAME=user
SHELL_PATH=/bin/bash
LOCALE=C.UTF-8
TIMEZONE=UTC
ENABLE_SSH=yes
ENABLE_SUDO=yes
ENABLE_NETWORK=yes
COPY_DNS=yes
RUN_SECOND_STAGE=yes
REGISTER_ROOTFS=yes
CREATE_PROJECT=yes
POST_WORKFLOW=health_audit
COMPRESSION=zstd
EOF_PROFILE
}

v89_install_builtin_presets(){
  v89_preset_write devuan-minimal devuan excalibur arm64 debootstrap sysvinit 'ca-certificates curl wget bash nano openssh-client openssh-server sudo tzdata locales'
  v89_preset_write devuan-development devuan excalibur arm64 debootstrap sysvinit 'ca-certificates curl wget bash bash-completion nano vim git make cmake pkg-config openssh-client openssh-server sudo cron logrotate tzdata locales'
  v89_preset_write alpine-minimal alpine v3.22 arm64 apk openrc 'alpine-base bash nano curl wget ca-certificates openssh sudo tzdata'
  v89_preset_write debian-minimal debian trixie arm64 debootstrap sysvinit 'ca-certificates curl wget bash nano openssh-client openssh-server sudo tzdata locales'
  v89_preset_write void-minimal void current arm64 xbps runit 'base-system bash nano curl wget ca-certificates openssh sudo tzdata'
}

v89_profile_library_save(){
  v87_profile_defaults
  name=$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME); [ -n "$name" ] || name=profile
  id=$(v89_safe_id "$name"); [ -n "$id" ] || id=profile
  dst="$V89_PROFILE_LIBRARY/$id.profile"
  [ -e "$dst" ] && ui_yesno 'Replace saved profile' "Replace $dst?" || true
  cp "$V87_BUILD_PROFILE" "$dst" && ui_msg 'Build profiles' "Saved: $dst"
}

v89_profile_select_file(){
  dir=$1; title=$2; set --
  for f in "$dir"/*.profile; do [ -f "$f" ] || continue; id=$(basename "$f" .profile); desc="$(v87_profile_get "$f" DISTRO) $(v87_profile_get "$f" RELEASE) / $(v87_profile_get "$f" ARCH)"; set -- "$@" "$id" "$desc"; done
  [ "$#" -gt 0 ] || { ui_msg "$title" 'No profiles are available.'; return 1; }
  choice=$(ui_menu "$title" 'Select a profile.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return 1; };
  printf '%s/%s.profile\n' "$dir" "$choice"
}

v89_profile_apply(){ src=$1; v89_profile_copy "$src" "$V87_BUILD_PROFILE" && ui_msg 'Build profiles' "Activated: $(v89_profile_name "$src")"; }
v89_profile_apply_preset(){ v89_install_builtin_presets; src=$(v89_profile_select_file "$V89_PRESET_DIR" 'Build profile presets') || return; v89_profile_apply "$src"; }
v89_profile_load_saved(){ src=$(v89_profile_select_file "$V89_PROFILE_LIBRARY" 'Saved build profiles') || return; v89_profile_apply "$src"; }

v89_profile_clone(){
  v87_profile_defaults
  name=$(ui_input 'Clone build profile' 'New profile name:' "$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME)-copy") || return
  id=$(v89_safe_id "$name"); [ -n "$id" ] || { ui_msg Error 'Invalid profile name.'; return 1; }
  dst="$V89_PROFILE_LIBRARY/$id.profile"; cp "$V87_BUILD_PROFILE" "$dst" || return
  v87_profile_set "$dst" PROFILE_NAME "$name"
  ui_msg 'Build profiles' "Cloned to: $dst"
}

v89_profile_compare_files(){
  a=$1; b=$2
  awk -F= 'NF{key=$1; sub(/^[^=]*=/,""); val=$0; print key "\t" val}' "$a" | sort >"$STATE_DIR/build-v89/a.$$"
  awk -F= 'NF{key=$1; sub(/^[^=]*=/,""); val=$0; print key "\t" val}' "$b" | sort >"$STATE_DIR/build-v89/b.$$"
  join -t "$(printf '\t')" -a1 -a2 -e '<unset>' -o 0,1.2,2.2 "$STATE_DIR/build-v89/a.$$" "$STATE_DIR/build-v89/b.$$" 2>/dev/null | awk -F '\t' '$2!=$3{printf "%-22s | %-28s | %s\n",$1,$2,$3}'
  rm -f "$STATE_DIR/build-v89/a.$$" "$STATE_DIR/build-v89/b.$$"
}

v89_profile_compare(){
  v87_profile_defaults
  other=$(v89_profile_select_file "$V89_PROFILE_LIBRARY" 'Compare with saved profile') || return
  out=$(v89_profile_compare_files "$V87_BUILD_PROFILE" "$other")
  [ -n "$out" ] || out='Profiles are identical.'
  ui_text 'Build profile comparison' "Current | Saved\n\n$out"
}

v89_profile_validate_report(){
  v87_profile_defaults
  tmp="$STATE_DIR/build-v89/validation.$$"; mkdir -p "$(dirname "$tmp")"
  {
    printf 'iSH-AOK Config 8.9.0 — Build Profile Validation\n\n'
    printf 'Profile: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" PROFILE_NAME)"
    printf 'Distribution: %s %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO)" "$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE)"
    printf 'Architecture: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" ARCH)"
    printf 'Backend: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)"
    printf 'Destination: %s\n\n' "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)"
    if v87_profile_validate >/dev/null 2>&1; then printf '[PASS] profile schema\n'; else printf '[FAIL] profile schema\n'; fi
    boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP)
    case $boot in debootstrap|mmdebstrap|apk|pacstrap|dnf|xbps|build_fs) cmd=$(v88_backend_command 2>/dev/null || true);; stage3) cmd=tar;; esac
    [ -n "${cmd:-}" ] && command -v "$cmd" >/dev/null 2>&1 && printf '[PASS] backend command: %s\n' "$cmd" || printf '[WARN] backend command unavailable: %s\n' "${cmd:-$boot}"
    dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); case $dest in /AOK/roots/*|/root/*|/home/*) printf '[PASS] destination safety pattern\n';; *) printf '[WARN] unusual destination path\n';; esac
    printf '[INFO] package count: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" PACKAGES | awk '{print NF}')"
  } >"$tmp"
  cat "$tmp"; rm -f "$tmp"
}

v89_profile_manager_menu(){
  v89_install_builtin_presets
  while :; do
    c=$(ui_menu 'Build Profiles and Presets' 'Create, reuse, compare and validate guided RootFS build profiles.' preset 'Apply a distribution preset' wizard 'Edit active profile with guided selections' save 'Save active profile to the profile library' load 'Load a saved profile' clone 'Clone active profile' compare 'Compare active profile with a saved profile' summary 'Review active profile' validate 'Detailed validation summary' plan 'Generate staged build plan') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in preset) v89_profile_apply_preset;; wizard) v87_build_profile_wizard;; save) v89_profile_library_save;; load) v89_profile_load_saved;; clone) v89_profile_clone;; compare) v89_profile_compare;; summary) v87_profile_summary;; validate) ui_text 'Profile validation' "$(v89_profile_validate_report)";; plan) p=$(v88_plan_generate); ui_text 'Build plan' "$(cat "$p")";; esac
  done
}

# v8.9 canonical build menu: profiles and execution are first-class, duplicate routes remain nested.
aok_builder_studio(){ while :; do c=$(ui_menu 'RootFS Build Studio' "Active RootFS: $(active_rootfs)" profiles 'Build profiles and distribution presets' execution 'Build execution, resume and recovery' recipes 'Build recipes and queue' projects 'RootFS projects' import 'Builder backends and RootFS import' validate 'Compatibility and preflight tools' artifacts 'Artifacts, archives and exports' overlays 'Overlay management' reports 'Build reports and logs') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in profiles) v89_profile_manager_menu;; execution) v88_build_execution_menu;; recipes) v89_recipes_queue_menu;; projects) rootfs_projects_menu;; import) aok_build_menu;; validate) aok_advanced_tools_menu;; artifacts) rootfs_import_export_studio;; overlays) overlay_studio_menu_v72 2>/dev/null || aok_more_options_menu;; reports) aok_build_logs;; esac; done; }
v89_recipes_queue_menu(){ while :; do c=$(ui_menu 'Build Recipes and Queue' 'Reusable definitions and scheduled build plans.' recipes 'Build recipe library' queue 'Build queue and plans' profile 'Active build-profile summary' plan 'Generate current staged plan') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in recipes) build_recipes_menu;; queue) aok_build_queue_menu;; profile) v87_profile_summary;; plan) p=$(v88_plan_generate); ui_text 'Build plan' "$(cat "$p")";; esac; done; }

v89_build_profiles_report(){ v89_install_builtin_presets; printf 'iSH-AOK Config 8.9.0 — Build Profiles and Presets\n\n'; printf 'Active profile: %s\n' "$V87_BUILD_PROFILE"; printf 'Preset directory: %s\n' "$V89_PRESET_DIR"; printf 'Saved profile directory: %s\n\n' "$V89_PROFILE_LIBRARY"; v89_profile_validate_report; printf '\nBuilt-in presets:\n'; for f in "$V89_PRESET_DIR"/*.profile; do [ -f "$f" ] && printf '  %s\n' "$(basename "$f" .profile)"; done; }
