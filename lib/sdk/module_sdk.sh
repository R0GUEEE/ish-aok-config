#!/bin/sh

V75_MODULE_STATE=${V75_MODULE_STATE:-$STATE_DIR/modules}
V75_MODULE_INDEX=${V75_MODULE_INDEX:-$V75_MODULE_STATE/index.tsv}
V75_DISABLED_MODULES=${V75_DISABLED_MODULES:-$V75_MODULE_STATE/disabled.list}
V75_PLUGIN_DIR=${V75_PLUGIN_DIR:-${HOME:-/root}/.local/share/ish-aok-config/plugins}
V75_SYSTEM_EXTENSION_DIR=${V75_SYSTEM_EXTENSION_DIR:-$ISH_AOK_CONFIG_ROOT/extensions}
mkdir -p "$V75_MODULE_STATE" "$V75_PLUGIN_DIR" 2>/dev/null || true

sdk_conf_get(){
  _sdk_file=$1 _sdk_key=$2
  awk -F= -v k="$_sdk_key" '$1==k{sub(/^[^=]*=/,""); gsub(/^\047|\047$/,""); gsub(/^"|"$/,""); print; exit}' "$_sdk_file" 2>/dev/null
}

sdk_valid_id(){ case ${1:-} in ''|*[!A-Za-z0-9_.-]*) return 1;; *) return 0;; esac; }
sdk_disabled(){ grep -Fx "$1" "$V75_DISABLED_MODULES" >/dev/null 2>&1; }

sdk_requirement_ok(){
  _sdk_req=$1
  case $_sdk_req in
    '') return 0;;
    rootfs) [ -d "$(active_rootfs 2>/dev/null)" ];;
    root) [ "$(id -u 2>/dev/null || echo 1)" -eq 0 ];;
    network) command -v ping >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1;;
    package-manager) [ "${PKG_MGR:-unknown}" != unknown ];;
    init:*) [ "${INIT_SYSTEM:-unknown}" = "${_sdk_req#init:}" ];;
    distro:*) [ "${DISTRO_ID:-unknown}" = "${_sdk_req#distro:}" ];;
    arch:*) [ "${ARCH:-unknown}" = "${_sdk_req#arch:}" ];;
    command:*) command -v "${_sdk_req#command:}" >/dev/null 2>&1;;
    file:*) [ -e "${_sdk_req#file:}" ];;
    *) command -v "$_sdk_req" >/dev/null 2>&1;;
  esac
}

sdk_requirements_status(){
  _sdk_reqs=$1 _sdk_missing=
  _sdk_oldifs=$IFS; IFS=,
  for _sdk_req in $_sdk_reqs; do
    IFS=$_sdk_oldifs
    _sdk_req=$(printf '%s' "$_sdk_req" | sed 's/^ *//;s/ *$//')
    [ -n "$_sdk_req" ] || { IFS=,; continue; }
    sdk_requirement_ok "$_sdk_req" || _sdk_missing="${_sdk_missing}${_sdk_missing:+,}$_sdk_req"
    IFS=,
  done
  IFS=$_sdk_oldifs
  printf '%s\n' "$_sdk_missing"
}

sdk_validate_manifest(){
  _sdk_manifest=$1
  [ -r "$_sdk_manifest" ] || return 1
  _sdk_id=$(sdk_conf_get "$_sdk_manifest" id)
  _sdk_title=$(sdk_conf_get "$_sdk_manifest" title)
  _sdk_version=$(sdk_conf_get "$_sdk_manifest" version)
  _sdk_entry=$(sdk_conf_get "$_sdk_manifest" entry)
  sdk_valid_id "$_sdk_id" || return 2
  [ -n "$_sdk_title" ] && [ -n "$_sdk_version" ] || return 3
  case $_sdk_entry in /*) return 4;; *'..'*) return 4;; esac
  [ -z "$_sdk_entry" ] || [ -r "$(dirname "$_sdk_manifest")/$_sdk_entry" ] || return 5
  return 0
}

sdk_scan_one(){
  _sdk_manifest=$1 _sdk_origin=$2
  sdk_validate_manifest "$_sdk_manifest" || return 0
  _sdk_id=$(sdk_conf_get "$_sdk_manifest" id)
  _sdk_title=$(sdk_conf_get "$_sdk_manifest" title)
  _sdk_category=$(sdk_conf_get "$_sdk_manifest" category); [ -n "$_sdk_category" ] || _sdk_category=Extensions
  _sdk_version=$(sdk_conf_get "$_sdk_manifest" version)
  _sdk_entry=$(sdk_conf_get "$_sdk_manifest" entry)
  _sdk_requires=$(sdk_conf_get "$_sdk_manifest" requires)
  _sdk_description=$(sdk_conf_get "$_sdk_manifest" description)
  _sdk_status=enabled
  sdk_disabled "$_sdk_id" && _sdk_status=disabled
  _sdk_missing=$(sdk_requirements_status "$_sdk_requires")
  [ -n "$_sdk_missing" ] && _sdk_status=unavailable
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$_sdk_id" "$_sdk_title" "$_sdk_category" "$_sdk_version" "$_sdk_status" "$_sdk_origin" "$_sdk_manifest" "$_sdk_entry" "$_sdk_requires" "$_sdk_description" >>"$V75_MODULE_INDEX.tmp"
}

sdk_discover_modules(){
  : >"$V75_MODULE_INDEX.tmp"
  for _sdk_base in "$V75_SYSTEM_EXTENSION_DIR" "$V75_PLUGIN_DIR"; do
    [ -d "$_sdk_base" ] || continue
    _sdk_origin=builtin; [ "$_sdk_base" = "$V75_PLUGIN_DIR" ] && _sdk_origin=user
    find "$_sdk_base" -type f \( -name module.conf -o -name plugin.conf \) 2>/dev/null | sort | while IFS= read -r _sdk_m; do sdk_scan_one "$_sdk_m" "$_sdk_origin"; done
  done
  mv "$V75_MODULE_INDEX.tmp" "$V75_MODULE_INDEX"
}

sdk_source_modules(){
  sdk_discover_modules
  while IFS="$(printf '\t')" read -r _sdk_id _sdk_title _sdk_cat _sdk_ver _sdk_status _sdk_origin _sdk_manifest _sdk_entry _sdk_req _sdk_desc; do
    [ "$_sdk_status" = enabled ] || continue
    [ -n "$_sdk_entry" ] || continue
    _sdk_file=$(dirname "$_sdk_manifest")/$_sdk_entry
    [ -r "$_sdk_file" ] && . "$_sdk_file"
  done <"$V75_MODULE_INDEX"
}


sdk_register_workflows(){
  [ -r "$V75_MODULE_INDEX" ] || sdk_discover_modules
  [ -n "${V74_PIPELINE_DIR:-}" ] || return 0
  mkdir -p "$V74_PIPELINE_DIR" 2>/dev/null || true
  while IFS="$(printf '\t')" read -r _sdk_id _sdk_title _sdk_cat _sdk_ver _sdk_status _sdk_origin _sdk_manifest _sdk_entry _sdk_req _sdk_desc; do
    [ "$_sdk_status" = enabled ] || continue
    _sdk_patterns=$(sdk_conf_get "$_sdk_manifest" workflows)
    [ -n "$_sdk_patterns" ] || continue
    _sdk_dir=$(dirname "$_sdk_manifest")
    printf '%s\n' "$_sdk_patterns" | tr ',' '\n' | while IFS= read -r _sdk_pattern; do
      _sdk_pattern=$(printf '%s' "$_sdk_pattern" | sed 's/^ *//;s/ *$//')
      case $_sdk_pattern in ''|/*|*'..'*) continue;; esac
      for _sdk_wf in "$_sdk_dir"/$_sdk_pattern; do
        [ -r "$_sdk_wf" ] || continue
        _sdk_name=$(basename "$_sdk_wf")
        cp "$_sdk_wf" "$V74_PIPELINE_DIR/ext-${_sdk_id}-${_sdk_name}" 2>/dev/null || true
      done
    done
  done <"$V75_MODULE_INDEX"
}

sdk_register_actions(){
  [ -r "$V75_MODULE_INDEX" ] || sdk_discover_modules
  while IFS="$(printf '\t')" read -r _sdk_id _sdk_title _sdk_cat _sdk_ver _sdk_status _sdk_origin _sdk_manifest _sdk_entry _sdk_req _sdk_desc; do
    [ "$_sdk_status" = enabled ] || continue
    _sdk_actions=$(sdk_conf_get "$_sdk_manifest" actions)
    [ -n "$_sdk_actions" ] || continue
    _sdk_oldifs=$IFS; IFS=,
    for _sdk_action in $_sdk_actions; do
      IFS=$_sdk_oldifs
      _sdk_action=$(printf '%s' "$_sdk_action" | sed 's/^ *//;s/ *$//')
      _sdk_aid=$(printf '%s' "$_sdk_action" | cut -d: -f1)
      _sdk_handler=$(printf '%s' "$_sdk_action" | cut -d: -f2)
      _sdk_atitle=$(printf '%s' "$_sdk_action" | cut -d: -f3-)
      [ -n "$_sdk_aid" ] && [ -n "$_sdk_handler" ] || { IFS=,; continue; }
      [ -n "$_sdk_atitle" ] || _sdk_atitle=$_sdk_title
      command_register "ext.$_sdk_id.$_sdk_aid" "$_sdk_atitle" "$_sdk_cat" "$_sdk_handler" "${_sdk_desc:-Dynamic extension action}"
      IFS=,
    done
    IFS=$_sdk_oldifs
  done <"$V75_MODULE_INDEX"
}

sdk_enable(){ sed -i.bak "/^$(printf '%s' "$1" | sed 's/[.[\*^$]/\\&/g')$/d" "$V75_DISABLED_MODULES" 2>/dev/null || true; rm -f "$V75_DISABLED_MODULES.bak"; sdk_discover_modules; }
sdk_disable(){ mkdir -p "$(dirname "$V75_DISABLED_MODULES")"; grep -Fx "$1" "$V75_DISABLED_MODULES" >/dev/null 2>&1 || printf '%s\n' "$1" >>"$V75_DISABLED_MODULES"; sdk_discover_modules; }

sdk_module_report(){
  sdk_discover_modules
  printf '%-24s %-12s %-10s %-9s %s\n' ID CATEGORY VERSION STATUS TITLE
  awk -F '\t' '{printf "%-24s %-12s %-10s %-9s %s\n",$1,$3,$4,$5,$2}' "$V75_MODULE_INDEX"
}

sdk_module_details(){
  _sdk_id=$1
  awk -F '\t' -v id="$_sdk_id" '$1==id{printf "ID: %s\nTitle: %s\nCategory: %s\nVersion: %s\nStatus: %s\nOrigin: %s\nManifest: %s\nEntry: %s\nRequires: %s\nDescription: %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10}' "$V75_MODULE_INDEX"
}

sdk_install_local_plugin(){
  src=$(ui_input 'Install extension' 'Path to plugin directory or tar archive') || return
  [ -e "$src" ] || { ui_msg Error "Not found: $src"; return 1; }
  tmp=
  case $src in
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz)
      tmp=$(mktemp -d "${TMPDIR:-/tmp}/ish-aok-plugin.XXXXXX") || return 1
      tar -xf "$src" -C "$tmp" || { rm -rf "$tmp"; ui_msg Error 'Could not extract plugin archive.'; return 1; }
      src=$(find "$tmp" -type f -name plugin.conf -print | head -n1); [ -n "$src" ] && src=$(dirname "$src") || { rm -rf "$tmp"; ui_msg Error 'plugin.conf not found.'; return 1; };;
  esac
  manifest=$src/plugin.conf
  sdk_validate_manifest "$manifest" || { [ -n "$tmp" ] && rm -rf "$tmp"; ui_msg Error 'Plugin manifest is invalid.'; return 1; }
  id=$(sdk_conf_get "$manifest" id); dest=$V75_PLUGIN_DIR/$id
  [ -e "$dest" ] && { ui_yesno Replace "Replace installed plugin $id?" || { [ -n "$tmp" ] && rm -rf "$tmp"; return; }; rm -rf "$dest"; }
  mkdir -p "$dest" && cp -R "$src"/. "$dest"/ || return 1
  [ -n "$tmp" ] && rm -rf "$tmp"
  sdk_enable "$id"; activity_add plugin "Installed extension $id"; ui_msg Installed "Installed extension: $id"
}

sdk_remove_user_plugin(){
  sdk_discover_modules; set --
  while IFS="$(printf '\t')" read -r id title category version status origin manifest entry requires description; do [ "$origin" = user ] && set -- "$@" "$id" "$title"; done <"$V75_MODULE_INDEX"
  [ "$#" -gt 0 ] || { ui_msg Plugins 'No user extensions are installed.'; return; }
  id=$(ui_menu 'Remove extension' 'Choose an installed user extension.' "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
  ui_yesno Remove "Remove $id?" || return
  rm -rf "$V75_PLUGIN_DIR/$id"; sdk_enable "$id"; activity_add plugin "Removed extension $id"
}
