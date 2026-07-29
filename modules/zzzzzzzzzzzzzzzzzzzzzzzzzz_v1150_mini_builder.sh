#!/bin/sh
# v11.5 streamlined mini RootFS builder.
#
# One screen, minimal defaults, and space-to-select checklists for everything
# that varies. The configuration lives in its own file so nothing touches the
# active build profile until a build actually starts, and any configuration can
# be saved as a reusable template.

V1150_CONFIG=${V1150_CONFIG:-$V1101_STATE_DIR/mini-build.conf}
V1150_TEMPLATE_DIR=${V1150_TEMPLATE_DIR:-$V1101_STATE_DIR/mini-templates}

v1150_get(){ sed -n "s/^$1=//p" "$V1150_CONFIG" 2>/dev/null | tail -n 1; }
v1150_set(){
  mkdir -p "$(dirname "$V1150_CONFIG")" 2>/dev/null || true
  _t="$V1150_CONFIG.tmp.$$"
  { grep -v "^$1=" "$V1150_CONFIG" 2>/dev/null || true; printf '%s=%s\n' "$1" "$2"; } >"$_t" && mv "$_t" "$V1150_CONFIG"
}

# A mini RootFS: smallest useful Alpine on the architecture iSH-AOK runs natively.
v1150_defaults(){
  [ -f "$V1150_CONFIG" ] && return 0
  mkdir -p "$(dirname "$V1150_CONFIG")" 2>/dev/null || true
  cat >"$V1150_CONFIG" <<'EOF_MINI'
DISTRO=alpine
RELEASE=latest-stable
ARCH=x86
DEST=/AOK/roots/mini-alpine
SETS=minimal
OPTIONS=stripdocs nocache network
EOF_MINI
}

v1150_distro_list(){
  for _f in "$V1101_DATA_DIR"/distributions/*.conf; do
    [ -f "$_f" ] || continue
    _b=$(basename "$_f" .conf)
    printf '%s|%s\n' "$_b" "$(sed -n 's/^PACKAGE_MANAGER=//p' "$_f" | head -n 1)"
  done
}

v1150_arch_list(){
  _f=$V1101_DATA_DIR/distributions/$(v1150_get DISTRO).conf
  _a=$(sed -n 's/^ARCHES=//p' "$_f" 2>/dev/null | head -n 1)
  [ -n "$_a" ] || _a='x86 x86_64 aarch64'
  printf '%s' "$_a"
}

v1150_release_default(){
  case $1 in
    alpine) printf latest-stable;;
    arch|gentoo) printf current;;
    fedora) printf latest;;
    debian|devuan|ubuntu|void) printf stable;;
    *) printf stable;;
  esac
}

v1150_destination_default(){ printf '/AOK/roots/mini-%s' "$1"; }

# Keep the current architecture when it is supported. Otherwise prefer the
# 32-bit x86 spelling used by the selected distribution, which is the native
# iSH target, and finally fall back to the first advertised architecture.
v1150_compatible_arch(){
  _wanted=$1
  _arches=$(v1150_arch_list)
  case " $_arches " in *" $_wanted "*) printf '%s' "$_wanted"; return;; esac
  case $_wanted in
    x86|i386|i486|i586|i686)
      for _candidate in x86 i386; do
        case " $_arches " in *" $_candidate "*) printf '%s' "$_candidate"; return;; esac
      done
      ;;
    x86_64|amd64)
      for _candidate in x86_64 amd64; do
        case " $_arches " in *" $_candidate "*) printf '%s' "$_candidate"; return;; esac
      done
      ;;
    aarch64|arm64)
      for _candidate in aarch64 arm64; do
        case " $_arches " in *" $_candidate "*) printf '%s' "$_candidate"; return;; esac
      done
      ;;
  esac
  set -- $_arches
  printf '%s' "${1:-x86}"
}

v1150_packages(){
  _sets=$(v1150_get SETS)
  [ -n "$_sets" ] || _sets=minimal
  v1101_packages_for_sets "$(printf '%s' "$_sets" | tr ' ' ',')" "$(v1150_get DISTRO)" 2>/dev/null || true
}

v1150_package_count(){ printf '%s' "$(v1150_packages)" | wc -w | tr -d ' '; }

v1150_option_on(){ case " $(v1150_get OPTIONS) " in *" $1 "*) return 0;; *) return 1;; esac; }

v1150_summary(){
  printf 'Distribution: %s %s (%s)\n' "$(v1150_get DISTRO)" "$(v1150_get RELEASE)" "$(v1150_get ARCH)"
  printf 'Destination:  %s\n' "$(v1150_get DEST)"
  printf 'Components:   %s\n' "$(v1150_get SETS)"
  printf 'Options:      %s\n' "$(v1150_get OPTIONS)"
  printf 'Packages:     %s\n\n' "$(v1150_package_count)"
  printf 'Package list:\n%s\n' "$(v1150_packages | tr ' ' '\n')"
}

v1150_header(){
  printf 'Target: %s %s / %s\nDestination: %s\nComponents: %s (%s packages)' \
    "$(v1150_get DISTRO)" "$(v1150_get RELEASE)" "$(v1150_get ARCH)" \
    "$(v1150_get DEST)" "$(v1150_get SETS)" "$(v1150_package_count)"
}

v1150_target_menu(){
  _old_distro=$(v1150_get DISTRO)
  _old_release=$(v1150_get RELEASE)
  _old_arch=$(v1150_get ARCH)
  _old_dest=$(v1150_get DEST)
  set --
  while IFS='|' read -r _id _pm; do
    [ -n "$_id" ] || continue
    _state=off; [ "$_id" = "$(v1150_get DISTRO)" ] && _state=on
    set -- "$@" "$_id" "$_id ($_pm)" "$_state"
  done <<EOF_D
$(v1150_distro_list)
EOF_D
  _d=$(ui_radiolist 'Distribution' 'Select the distribution for the mini RootFS.' "$@") || return "${UI_MENU_BACK_RC:-90}"
  [ -n "$_d" ] || return "${UI_MENU_BACK_RC:-90}"
  v1150_set DISTRO "$_d"

  if [ "$_d" != "$_old_distro" ]; then
    [ "$_old_release" = "$(v1150_release_default "$_old_distro")" ] && v1150_set RELEASE "$(v1150_release_default "$_d")"
    [ "$_old_dest" = "$(v1150_destination_default "$_old_distro")" ] && v1150_set DEST "$(v1150_destination_default "$_d")"
  fi
  v1150_set ARCH "$(v1150_compatible_arch "$_old_arch")"

  _r=$(ui_input 'Release' 'Release or suite:' "$(v1150_get RELEASE)") || return "${UI_MENU_BACK_RC:-90}"
  [ -n "$_r" ] && v1150_set RELEASE "$_r"

  set --
  for _a in $(v1150_arch_list); do
    _state=off; [ "$_a" = "$(v1150_get ARCH)" ] && _state=on
    set -- "$@" "$_a" "$_a" "$_state"
  done
  _sel=$(ui_radiolist 'Architecture' 'Select the target architecture. iSH-AOK runs x86 natively.' "$@") || return "${UI_MENU_BACK_RC:-90}"
  [ -n "$_sel" ] && v1150_set ARCH "$_sel"
}

# Space-to-select components.
v1150_components_menu(){
  _cur=" $(v1150_get SETS) "
  set --
  while IFS='|' read -r _id _label _desc _file; do
    [ -n "$_id" ] || continue
    _state=off
    case $_cur in *" $_id "*) _state=on;; esac
    set -- "$@" "$_id" "$_label — $_desc" "$_state"
  done <<EOF_S
$(v1101_package_set_list)
EOF_S
  _sel=$(ui_checklist 'Components' 'Space selects a component. A mini RootFS normally needs only Minimal.' "$@") || return 0
  if [ -z "$_sel" ]; then
    ui_yesno Components 'No components selected. Keep only the Minimal set?' || return 0
    _sel=minimal
  fi
  v1150_set SETS "$(printf '%s' "$_sel" | tr '\n' ' ' | sed 's/ *$//')"
}

# Space-to-select build options.
v1150_options_menu(){
  set --
  for _o in stripdocs nocache network ssh sudo archive; do
    case $_o in
      stripdocs) _l='Exclude man pages, documentation and locales';;
      nocache) _l='Do not keep a package cache inside the image';;
      network) _l='Copy DNS configuration into the RootFS';;
      ssh) _l='Install and enable an SSH server';;
      sudo) _l='Install sudo or doas';;
      archive) _l='Create a compressed archive after building';;
    esac
    _state=off; v1150_option_on "$_o" && _state=on
    set -- "$@" "$_o" "$_l" "$_state"
  done
  _sel=$(ui_checklist 'Build options' 'Space selects an option. The first three keep the image small.' "$@") || return 0
  v1150_set OPTIONS "$(printf '%s' "$_sel" | tr '\n' ' ' | sed 's/ *$//')"
}

# A single checklist is the fast path: package components and image behavior
# are selected together with Space. Prefixes keep the two result groups clear
# without relying on non-POSIX arrays.
v1150_features_menu(){
  _sets=" $(v1150_get SETS) "
  set --
  while IFS='|' read -r _id _label _desc _file; do
    [ -n "$_id" ] || continue
    _state=off; case $_sets in *" $_id "*) _state=on;; esac
    set -- "$@" "set_$_id" "Component: $_label — $_desc" "$_state"
  done <<EOF_S
$(v1101_package_set_list)
EOF_S
  for _o in stripdocs nocache network ssh sudo archive; do
    case $_o in
      stripdocs) _l='Small: exclude documentation and locales';;
      nocache) _l='Small: remove downloaded package caches';;
      network) _l='Copy DNS configuration into the RootFS';;
      ssh) _l='Install and enable an SSH server';;
      sudo) _l='Install sudo or doas';;
      archive) _l='Create a compressed archive after building';;
    esac
    _state=off; v1150_option_on "$_o" && _state=on
    set -- "$@" "opt_$_o" "Option: $_l" "$_state"
  done
  _sel=$(ui_checklist 'Mini RootFS contents' 'Use Space to select components and options. Minimal plus the three Small/network defaults produces a compact, usable image.' "$@") || return "${UI_MENU_BACK_RC:-90}"
  _new_sets=$(printf '%s\n' "$_sel" | sed -n 's/^set_//p' | tr '\n' ' ' | sed 's/ *$//')
  _new_options=$(printf '%s\n' "$_sel" | sed -n 's/^opt_//p' | tr '\n' ' ' | sed 's/ *$//')
  if [ -z "$_new_sets" ]; then
    ui_yesno Components 'No components selected. Use the Minimal component set?' || return 0
    _new_sets=minimal
  fi
  v1150_set SETS "$_new_sets"
  v1150_set OPTIONS "$_new_options"
}

v1150_destination_menu(){
  _d=$(ui_input Destination 'Directory for the new RootFS:' "$(v1150_get DEST)") || return "${UI_MENU_BACK_RC:-90}"
  [ -n "$_d" ] || return "${UI_MENU_BACK_RC:-90}"
  case $_d in
    /) ui_msg Destination 'The running system cannot be used as a build destination.'; return 0;;
  esac
  if [ -d "$_d" ] && [ -n "$(ls -A "$_d" 2>/dev/null)" ]; then
    ui_yesno Destination "$_d already exists and is not empty. Use it anyway?" || return 0
  fi
  v1150_set DEST "$_d"
}

v1150_template_file(){ printf '%s/%s.template' "$V1150_TEMPLATE_DIR" "$1"; }

v1150_template_list(){
  for _f in "$V1150_TEMPLATE_DIR"/*.template; do
    [ -f "$_f" ] || continue
    _n=$(basename "$_f" .template)
    printf '%s|%s %s/%s [%s]\n' "$_n" "$_n —" "$(sed -n 's/^DISTRO=//p' "$_f")" "$(sed -n 's/^ARCH=//p' "$_f")" "$(sed -n 's/^SETS=//p' "$_f")"
  done
}

v1150_template_save(){
  _n=$(ui_input 'Save template' 'Template name:' "$(v1150_get DISTRO)-mini") || return "${UI_MENU_BACK_RC:-90}"
  [ -n "$_n" ] || return 1
  case $_n in *[!A-Za-z0-9._-]*) ui_msg 'Save template' 'Use letters, digits, dot, dash or underscore only.'; return 1;; esac
  mkdir -p "$V1150_TEMPLATE_DIR" 2>/dev/null || true
  _f=$(v1150_template_file "$_n")
  [ -f "$_f" ] && { ui_yesno 'Save template' "Template $_n already exists. Overwrite?" || return 1; }
  {
    printf '# iSH-AOK mini RootFS template\n'
    printf 'DISTRO=%s\n' "$(v1150_get DISTRO)"
    printf 'RELEASE=%s\n' "$(v1150_get RELEASE)"
    printf 'ARCH=%s\n' "$(v1150_get ARCH)"
    printf 'DEST=%s\n' "$(v1150_get DEST)"
    printf 'SETS=%s\n' "$(v1150_get SETS)"
    printf 'OPTIONS=%s\n' "$(v1150_get OPTIONS)"
  } >"$_f" || { ui_msg 'Save template' "Could not write $_f."; return 1; }
  ui_msg 'Save template' "Saved as $_n."
}

v1150_template_load(){
  set --
  while IFS='|' read -r _n _label; do
    [ -n "$_n" ] || continue
    set -- "$@" "$_n" "$_label"
  done <<EOF_T
$(v1150_template_list)
EOF_T
  [ "$#" -gt 0 ] || { ui_msg Templates 'No templates have been saved yet.'; return 1; }
  _sel=$(ui_menu 'Load template' 'Select a saved configuration.' "$@") || return "${UI_MENU_BACK_RC:-90}"
  _f=$(v1150_template_file "$_sel")
  [ -r "$_f" ] || { ui_msg Templates "Template $_sel could not be read."; return 1; }
  for _k in DISTRO RELEASE ARCH DEST SETS OPTIONS; do
    _v=$(sed -n "s/^$_k=//p" "$_f" | tail -n 1)
    grep -q "^$_k=" "$_f" && v1150_set "$_k" "$_v"
  done
  ui_msg Templates "Loaded $_sel."
}

v1150_template_delete(){
  set --
  while IFS='|' read -r _n _label; do
    [ -n "$_n" ] || continue
    set -- "$@" "$_n" "$_label"
  done <<EOF_T
$(v1150_template_list)
EOF_T
  [ "$#" -gt 0 ] || { ui_msg Templates 'No templates have been saved yet.'; return 0; }
  _sel=$(ui_menu 'Delete template' 'Select a template to delete.' "$@") || return 0
  ui_yesno 'Delete template' "Delete $_sel?" || return 0
  rm -f "$(v1150_template_file "$_sel")"
  ui_msg Templates "Deleted $_sel."
}

v1150_template_menu(){
  while :; do
    _c=$(ui_menu Templates 'Save the current configuration for reuse, or load a saved one.' \
      save 'Save the current configuration as a template' \
      load 'Load a saved template' \
      delete 'Delete a saved template' \
      back 'Back') || { _r=$?; [ "$_r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_r"; }
    case $_c in
      save) v1150_template_save;;
      load) v1150_template_load;;
      delete) v1150_template_delete;;
      back) return 0;;
    esac
  done
}

# Publish the mini configuration into the active build profile, then run the
# existing resumable pipeline so builds stay recoverable.
v1150_apply_to_profile(){
  command -v v87_profile_defaults >/dev/null 2>&1 && v87_profile_defaults 2>/dev/null || true
  _f=$V87_BUILD_PROFILE
  v87_profile_set "$_f" PROFILE_NAME "mini-$(v1150_get DISTRO)"
  v87_profile_set "$_f" DISTRO "$(v1150_get DISTRO)"
  v87_profile_set "$_f" RELEASE "$(v1150_get RELEASE)"
  v87_profile_set "$_f" ARCH "$(v1150_get ARCH)"
  v87_profile_set "$_f" DEST "$(v1150_get DEST)"
  v87_profile_set "$_f" PACKAGE_SETS "$(v1150_get SETS)"
  v87_profile_set "$_f" PACKAGES "$(v1150_packages)"
  v87_profile_set "$_f" BOOTSTRAP "$(v1110_dist_get "$(v1150_get DISTRO)" BACKEND)"
  v87_profile_set "$_f" INIT "$(v1110_dist_get "$(v1150_get DISTRO)" INIT)"
  v1150_option_on ssh && v87_profile_set "$_f" ENABLE_SSH yes || v87_profile_set "$_f" ENABLE_SSH no
  v1150_option_on sudo && v87_profile_set "$_f" ENABLE_SUDO yes || v87_profile_set "$_f" ENABLE_SUDO no
  v1150_option_on network && v87_profile_set "$_f" COPY_DNS yes || v87_profile_set "$_f" COPY_DNS no
  v1150_option_on stripdocs && v87_profile_set "$_f" STRIP_DOCS yes || v87_profile_set "$_f" STRIP_DOCS no
  v1150_option_on nocache && v87_profile_set "$_f" KEEP_CACHE no || v87_profile_set "$_f" KEEP_CACHE yes
  v1150_option_on archive && v87_profile_set "$_f" CREATE_ARCHIVE yes || v87_profile_set "$_f" CREATE_ARCHIVE no
}

v1150_build(){
  [ -n "$(v1150_get DEST)" ] || { ui_msg Build 'Set a destination directory first.'; return 1; }
  ui_text 'Review the build' "$(v1150_summary)"
  ui_yesno 'Build mini RootFS' "Create the RootFS at $(v1150_get DEST)?\n\nThe staged pipeline can be resumed if it stops." || return 0
  v1150_apply_to_profile
  _ws=$(v1110_workspace_create) || { ui_msg Build 'Could not create a build workspace.'; return 1; }
  if v1110_pipeline_run "$_ws"; then
    ui_msg Build "Mini RootFS completed.\n\n$(v1150_get DEST)"
  else
    ui_msg Build "The build stopped and can be resumed from the Build Pipeline.\n\n$_ws"
  fi
}

v1150_review_menu(){
  while :; do
    _c=$(ui_menu 'Mini RootFS ready' "$(v1150_header)" \
      build 'Build now' \
      save_build 'Save as a template, then build' \
      save 'Save as a template' \
      review 'Review packages and full configuration' \
      edit 'Change the selections' \
      back 'Keep this configuration and go back') || return 0
    case $_c in
      build) v1150_build; return;;
      save_build) v1150_template_save && { v1150_build; return; };;
      save) v1150_template_save;;
      review) ui_text 'Mini RootFS configuration' "$(v1150_summary)";;
      edit) return 2;;
      back) return 0;;
    esac
  done
}

v1150_guided_create(){
  while :; do
    v1150_target_menu || return 0
    v1150_destination_menu || return 0
    v1150_features_menu || return 0
    if v1150_review_menu; then
      return 0
    else
      _review_rc=$?
      [ "$_review_rc" -eq 2 ] || return "$_review_rc"
    fi
  done
}

v1150_mini_builder_menu(){
  v1150_defaults
  command -v v1101_init >/dev/null 2>&1 && v1101_init >/dev/null 2>&1 || true
  while :; do
    _c=$(ui_menu 'Create Mini RootFS' "$(v1150_header)" \
      create 'Configure and create a mini RootFS' \
      load_create 'Load a saved template and create' \
      target 'Distribution, release and architecture' \
      destination 'Destination directory' \
      contents 'Components and options — space to select' \
      templates 'Save or load a configuration template' \
      review 'Review the resolved package list' \
      back 'Back') || { _r=$?; [ "$_r" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_r"; }
    case $_c in
      create) v1150_guided_create;;
      load_create) v1150_template_load && v1150_review_menu;;
      target) v1150_target_menu;;
      destination) v1150_destination_menu;;
      contents) v1150_features_menu;;
      templates) v1150_template_menu;;
      review) ui_text 'Mini RootFS configuration' "$(v1150_summary)";;
      back) return 0;;
    esac
  done
}

# The builder dashboard now leads with the streamlined mini builder.
v1110_builder_dashboard(){
  v1101_init >/dev/null 2>&1 || true
  while :; do
    choice=$(ui_menu 'RootFS Builder' "$(printf 'Resumable pipeline | Backend: %s\nTarget: %s %s / %s' "$(v1110_backend_name)" "$(v1101_profile_value DISTRO)" "$(v1101_profile_value RELEASE)" "$(v1101_profile_value ARCH)")" \
      mini 'Create Mini RootFS — guided, space-to-select' \
      pipeline 'Build Pipeline — validate, plan, run, resume and logs' \
      profiles 'Build profiles' \
      queue 'Build queue' \
      resources 'Package sets, repositories, keyrings and cache' \
      artifacts 'Artifacts and manifests' \
      advanced 'Advanced builder tools' \
      back 'Back') || return 0
    case $choice in
      mini) v1150_mini_builder_menu;; pipeline) v1110_pipeline_menu;; profiles) v1101_profile_menu;;
      queue) v1101_queue_menu;; resources) v1110_resources_menu;;
      artifacts) v1101_artifacts_menu;; advanced) v102_advanced_build_menu;; back) return 0;;
    esac
  done
}
v1100_builder_dashboard(){ v1110_builder_dashboard; }
v1101_builder_dashboard(){ v1110_builder_dashboard; }
