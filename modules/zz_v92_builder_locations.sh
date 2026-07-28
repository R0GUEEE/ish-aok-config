#!/bin/sh
# v9.2 Builder Destination Integration

v92_profile_location_select(){
  v87_profile_defaults
  d=$(v87_profile_get "$V87_BUILD_PROFILE" DISTRO); r=$(v87_profile_get "$V87_BUILD_PROFILE" RELEASE); a=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH)
  label=$(printf '%s-%s-%s' "${d:-rootfs}" "${r:-current}" "${a:-arm64}" | tr ' /' '--')
  current=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); [ -n "$current" ] || current=$(rootfs_location_default "$d" "$r" "$a")
  p=$(rootfs_location_select "$current" "$label") || return
  v87_profile_set "$V87_BUILD_PROFILE" DEST "$p"
  ui_msg 'Build profile' "RootFS destination set to:\n$p"
}

# Keep identity editing focused; destination now uses the location selector.
v92_profile_choose_identity(){
  for spec in 'PROFILE_NAME|Profile name|default' 'RELEASE|Distribution release|excalibur' 'MIRROR|Repository mirror URL|' 'HOSTNAME|Hostname|ish-aok' 'USER_NAME|Default user name|user' 'LOCALE|Locale|C.UTF-8' 'TIMEZONE|Timezone|UTC'; do
    k=${spec%%|*}; rest=${spec#*|}; label=${rest%%|*}; def=${rest#*|}; cur=$(v87_profile_get "$V87_BUILD_PROFILE" "$k"); [ -n "$cur" ] || cur=$def
    val=$(ui_input 'Build profile: Identity' "$label" "$cur") || return
    v87_profile_set "$V87_BUILD_PROFILE" "$k" "$val"
  done
}

v87_profile_validate(){
  v87_profile_defaults; errors=''
  for k in DISTRO RELEASE ARCH DEST BOOTSTRAP INIT SHELL_PATH; do v=$(v87_profile_get "$V87_BUILD_PROFILE" "$k"); [ -n "$v" ] || errors="$errors\nMissing: $k"; done
  dest=$(v87_profile_get "$V87_BUILD_PROFILE" DEST); msg=$(rootfs_location_validate "$dest" 2>&1) || errors="$errors\n$msg"
  arch=$(v87_profile_get "$V87_BUILD_PROFILE" ARCH); case $arch in arm64|aarch64|i386|amd64|x86_64|riscv64) :;; *) errors="$errors\nUnsupported ARCH: $arch";; esac
  boot=$(v87_profile_get "$V87_BUILD_PROFILE" BOOTSTRAP); case $boot in debootstrap|mmdebstrap|apk|pacstrap|dnf|xbps|stage3|build_fs) :;; *) errors="$errors\nUnknown BOOTSTRAP: $boot";; esac
  [ -z "$errors" ] || { ui_msg 'Build profile validation' "Validation failed:$errors"; return 1; }
  ui_msg 'Build profile validation' 'Profile is valid.'
}

v87_build_profile_wizard(){
  v87_profile_defaults
  while :; do
    c=$(ui_menu 'Build Profile Wizard' "RootFS destination: $(v87_profile_get "$V87_BUILD_PROFILE" DEST)" \
      distro 'Distribution preset' arch 'Architecture' location 'RootFS destination location' bootstrap 'Bootstrap backend' packages 'Package groups' features 'Build features' identity 'Identity and release' init 'Init system and default shell' compression 'Archive compression' summary 'Review profile summary' validate 'Validate profile' reset 'Reset to recommended defaults') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in
      distro) v87_profile_choose_distro;; arch) v87_profile_choose_arch;; location) v92_profile_location_select;; bootstrap) v87_profile_choose_bootstrap;; packages) v87_profile_choose_packages;; features) v87_profile_choose_options;; identity) v92_profile_choose_identity;; init) v87_profile_choose_init_shell;; compression) v87_profile_choose_compression;; summary) v87_profile_summary;; validate) v87_profile_validate;; reset) ui_yesno Reset 'Replace the current profile with recommended defaults?' && { rm -f "$V87_BUILD_PROFILE"; v87_profile_defaults; };;
    esac
  done
}

v92_builder_destination(){
  distro=$1; release=$2; arch=$3
  label=$(printf '%s-%s-%s' "$distro" "$release" "$arch" | tr ' /' '--')
  suggested=$(rootfs_location_default "$distro" "$release" "$arch")
  rootfs_location_select "$suggested" "$label"
}

# Direct builders now share the same location selector and safety checks.
aok_builder_debootstrap(){
  have debootstrap || { aok_install_hint debootstrap; return; }
  f=$(aok_build_profile_file); [ -r "$f" ] && . "$f"
  rel=${RELEASE:-stable}; arch=${ARCH:-arm64}; mirror=${MIRROR:-}
  dest=$(rootfs_location_select "${DEST:-$(rootfs_location_default debian "$rel" "$arch")}" "debian-$rel-$arch") || return
  v87_profile_set "$V87_BUILD_PROFILE" DEST "$dest"
  cmd="debootstrap --arch=$arch $rel '$dest'${mirror:+ '$mirror'}"; aok_command_preview "$cmd"; aok_confirm 'Run debootstrap builder?' && run_capture Debootstrap sh -c "$cmd"
}

aok_builder_apk(){
  have apk || { aok_install_hint apk; return; }
  branch=$(ui_input Alpine 'Version branch' v3.22) || return; arch=$(ui_input Alpine 'Architecture' aarch64) || return
  dest=$(v92_builder_destination alpine "$branch" "$arch") || return
  mirror=$(ui_input Alpine 'Mirror' 'https://dl-cdn.alpinelinux.org/alpine') || return
  cmd="mkdir -p '$dest/etc/apk' && echo '$mirror/$branch/main' > '$dest/etc/apk/repositories' && apk --root '$dest' --arch '$arch' --initdb add alpine-base"
  aok_command_preview "$cmd"; aok_confirm 'Build Alpine rootfs?' && run_capture Alpine as_root sh -c "$cmd"
}

aok_builder_pacstrap(){
  have pacstrap || { aok_install_hint pacstrap; return; }
  arch=$(ui_input Arch 'Architecture label' "${ARCH:-arm64}") || return
  dest=$(v92_builder_destination arch rolling "$arch") || return
  aok_confirm 'Run pacstrap base installation?' && run_capture Arch as_root pacstrap -c "$dest" base bash
}

aok_builder_dnf(){
  have dnf || have yum || { aok_install_hint dnf; return; }
  rel=$(ui_input DNF 'Release version' 43) || return; arch=$(ui_input DNF 'Architecture' aarch64) || return
  dest=$(v92_builder_destination fedora "$rel" "$arch") || return
  mgr=dnf; have dnf || mgr=yum
  cmd="$mgr -y --releasever='$rel' --installroot='$dest' --forcearch='$arch' --setopt=install_weak_deps=False install @core"
  aok_command_preview "$cmd"; aok_confirm 'Run DNF installroot?' && run_capture DNF as_root sh -c "$cmd"
}

aok_builder_xbps(){
  have xbps-install || { aok_install_hint xbps-install; return; }
  arch=$(ui_input XBPS 'Architecture' aarch64) || return
  repo=$(ui_input XBPS 'Repository URL' 'https://repo-default.voidlinux.org/current/aarch64') || return
  dest=$(v92_builder_destination void current "$arch") || return
  aok_confirm 'Build Void rootfs?' && run_capture XBPS as_root env XBPS_ARCH="$arch" xbps-install -Sy -R "$repo" -r "$dest" base-system
}

aok_import_directory(){
  src=$(ui_input Import 'Existing RootFS directory' '') || return; [ -d "$src" ] || { ui_msg Import 'Source directory was not found.'; return 1; }
  dst=$(rootfs_location_select "/AOK/roots/$(basename "$src")" "$(basename "$src")") || return
  aok_confirm "Import $src to $dst?" || return
  if have rsync; then run_capture Import as_root rsync -aH "$src/" "$dst/"; else mkdir -p "$dst" && run_capture Import as_root cp -a "$src/." "$dst/"; fi
}

# v8 recipe creation now records an explicit destination selected through the same API.
build_recipe_create(){
  id=$(v80_safe_id "$(ui_input 'Build recipe' 'Recipe ID' devuan-minimal)") || return; [ -n "$id" ] || return
  f="$V80_RECIPES_DIR/$id.recipe"; distro=$(ui_input 'Build recipe' 'Distribution' devuan) || return; release=$(ui_input 'Build recipe' 'Release' excalibur) || return; arch=$(ui_input 'Build recipe' 'Architecture' arm64) || return
  dest=$(rootfs_location_select "$(rootfs_location_default "$distro" "$release" "$arch")" "$distro-$release-$arch") || return
  bootstrap=$(ui_input 'Build recipe' 'Bootstrap method' debootstrap) || return; packages=$(ui_input 'Build recipe' 'Packages (space separated)' 'ca-certificates curl bash nano openssh-server') || return
  printf 'id=%s\ndistro=%s\nrelease=%s\narch=%s\ndestination=%s\nbootstrap=%s\npackages=%s\npost_workflow=%s\n' "$id" "$distro" "$release" "$arch" "$dest" "$bootstrap" "$packages" health_audit >"$f"; ui_msg Recipes "Saved: $f"
}

build_recipe_run(){
  id=$(build_recipe_select) || return; f="$V80_RECIPES_DIR/$id.recipe"; dest=$(v80_conf_get "$f" destination)
  [ -n "$dest" ] || dest=$(rootfs_location_default "$(v80_conf_get "$f" distro)" "$(v80_conf_get "$f" release)" "$(v80_conf_get "$f" arch)")
  ui_text 'Recipe execution plan' "Recipe: $id\nDistribution: $(v80_conf_get "$f" distro)\nRelease: $(v80_conf_get "$f" release)\nArchitecture: $(v80_conf_get "$f" arch)\nDestination: $dest\nBootstrap: $(v80_conf_get "$f" bootstrap)\nPackages: $(v80_conf_get "$f" packages)\n\nApply this recipe to the active build profile before execution."
  aok_confirm 'Load this recipe into the active build profile?' || return
  for pair in "DISTRO:$(v80_conf_get "$f" distro)" "RELEASE:$(v80_conf_get "$f" release)" "ARCH:$(v80_conf_get "$f" arch)" "DEST:$dest" "BOOTSTRAP:$(v80_conf_get "$f" bootstrap)" "PACKAGES:$(v80_conf_get "$f" packages)"; do k=${pair%%:*}; v=${pair#*:}; v87_profile_set "$V87_BUILD_PROFILE" "$k" "$v"; done
  v88_build_execution_menu
}

v92_location_manager_menu(){
  while :; do c=$(ui_menu 'RootFS Locations' 'Choose defaults and review recent build destinations.' select 'Select location for active build profile' recent 'View recent locations' registered 'View registered RootFS paths' report 'Location report' clear 'Clear recent locations') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; }; case $c in select) v92_profile_location_select;; recent) ui_text 'Recent RootFS locations' "$(rootfs_location_recent_paths)";; registered) ui_text 'Registered RootFS locations' "$(rootfs_registry_paths 2>/dev/null)";; report) ui_text 'RootFS location report' "$(rootfs_location_report)";; clear) ui_yesno 'RootFS locations' 'Clear recent RootFS locations?' && : >"$V92_RECENT_LOCATIONS";; esac; done
}

# Integrate location management into the canonical studio.
aok_builder_studio(){
  while :; do
    c=$(ui_menu 'RootFS Build Studio' "Destination: $(v87_profile_get "$V87_BUILD_PROFILE" DEST)" \
      profile 'Build profiles and presets' location 'RootFS destination locations' execution 'Build execution, resume and recovery' recipes 'Build recipes and queue' projects 'RootFS projects' backends 'Builder backends and RootFS import' validate 'Compatibility and preflight tools' artifacts 'Artifacts, archives and exports' overlays 'Overlay management' reports 'Build reports and logs') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in profile) v89_profile_manager_menu;; location) v92_location_manager_menu;; execution) v88_build_execution_menu;; recipes) v89_recipes_queue_menu;; projects) rootfs_projects_menu;; backends) v87_manual_builders_menu;; validate) aok_advanced_tools_menu;; artifacts) rootfs_import_export_studio;; overlays) overlay_studio_menu_v72 2>/dev/null || aok_more_options_menu;; reports) aok_build_logs;; esac
  done
}

v92_locations_report(){ rootfs_location_report; printf '\nActive build destination:\n  %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)"; }
