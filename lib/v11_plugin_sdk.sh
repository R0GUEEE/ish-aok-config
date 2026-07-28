#!/bin/sh
# iSH-AOK Config v11.2.0 Plugin and Distribution SDK.

V112_SDK_ROOT=${V112_SDK_ROOT:-$ISH_AOK_CONFIG_ROOT/sdk}
V112_PLUGIN_ROOT=${V112_PLUGIN_ROOT:-${XDG_DATA_HOME:-${HOME:-/root}/.local/share}/ish-aok-config/plugins}
V112_CATALOG_DIR=${V112_CATALOG_DIR:-$ISH_AOK_CONFIG_ROOT/data/v11/plugin-catalog}
V112_DIST_ROOT=${V112_DIST_ROOT:-$ISH_AOK_CONFIG_ROOT/data/v11/distributions}
V112_DISABLED=${V112_DISABLED:-${XDG_CONFIG_HOME:-${HOME:-/root}/.config}/ish-aok-config/disabled-plugins}
V112_INDEX=${V112_INDEX:-${TMPDIR:-/tmp}/ish-aok-v112-plugins.tsv}
V112_APP_VERSION=11.3.2

v112_trim(){ printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
v112_valid_id(){ case ${1:-} in ''|*[!a-z0-9._-]*|.*|-*) return 1;; *) return 0;; esac; }
v112_meta_get(){
  _f=$1 _k=$2
  awk -v k="$_k" '
    /^[[:space:]]*#/ {next}
    {line=$0; sub(/^[[:space:]]*/,"",line)}
    index(line,k":")==1 {sub("^[^:]*:[[:space:]]*","",line); gsub(/^\"|\"$/, "", line); print line; exit}
    index(line,k"=")==1 {sub("^[^=]*=[[:space:]]*","",line); gsub(/^\"|\"$/, "", line); print line; exit}
  ' "$_f" 2>/dev/null
}
v112_version_ge(){
  [ "$1" = "$2" ] && return 0
  _first=$(printf '%s\n%s\n' "$1" "$2" | awk -F. '{printf "%09d%09d%09d %s\n",$1,$2,$3,$0}' | sort | tail -n1 | sed 's/^[0-9]* //')
  [ "$_first" = "$1" ]
}
v112_plugin_manifest(){ [ -r "$1/plugin.yaml" ] && printf '%s\n' "$1/plugin.yaml" || printf '%s\n' "$1/plugin.conf"; }
v112_plugin_validate(){
  _m=$1; [ -r "$_m" ] || { echo 'missing manifest'; return 1; }
  _id=$(v112_meta_get "$_m" id); _ver=$(v112_meta_get "$_m" version); _entry=$(v112_meta_get "$_m" entry)
  v112_valid_id "$_id" || { echo 'invalid or missing id'; return 2; }
  [ -n "$_ver" ] || { echo 'missing version'; return 3; }
  case $_entry in ''|/*|*'..'*) echo 'invalid or missing entry'; return 4;; esac
  [ -r "$(dirname "$_m")/$_entry" ] || { echo 'entry file missing'; return 5; }
  _min=$(v112_meta_get "$_m" min_core_version)
  [ -z "$_min" ] || v112_version_ge "$V112_APP_VERSION" "$_min" || { echo "requires core >= $_min"; return 6; }
  sh -n "$(dirname "$_m")/$_entry" || { echo 'entry has shell syntax errors'; return 7; }
  echo 'valid'
}
v112_plugin_disabled(){ grep -Fx "$1" "$V112_DISABLED" >/dev/null 2>&1; }
v112_plugin_enable(){ mkdir -p "$(dirname "$V112_DISABLED")"; [ -f "$V112_DISABLED" ] || : >"$V112_DISABLED"; grep -Fvx "$1" "$V112_DISABLED" >"$V112_DISABLED.tmp" || true; mv "$V112_DISABLED.tmp" "$V112_DISABLED"; }
v112_plugin_disable(){ mkdir -p "$(dirname "$V112_DISABLED")"; grep -Fx "$1" "$V112_DISABLED" >/dev/null 2>&1 || printf '%s\n' "$1" >>"$V112_DISABLED"; }
v112_plugin_scan(){
  : >"$V112_INDEX"
  for _base in "$ISH_AOK_CONFIG_ROOT/plugins" "$V112_PLUGIN_ROOT"; do
    [ -d "$_base" ] || continue
    find "$_base" -mindepth 1 -maxdepth 2 -type f \( -name plugin.yaml -o -name plugin.conf \) 2>/dev/null | sort | while IFS= read -r _m; do
      _id=$(v112_meta_get "$_m" id); [ -n "$_id" ] || continue
      _title=$(v112_meta_get "$_m" name); [ -n "$_title" ] || _title=$_id
      _ver=$(v112_meta_get "$_m" version); _cat=$(v112_meta_get "$_m" category); [ -n "$_cat" ] || _cat=Utilities
      _deps=$(v112_meta_get "$_m" dependencies); _status=enabled
      v112_plugin_disabled "$_id" && _status=disabled
      v112_plugin_validate "$_m" >/dev/null 2>&1 || _status=invalid
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_id" "$_title" "$_ver" "$_cat" "$_status" "$_deps" "$_m" >>"$V112_INDEX"
    done
  done
}
v112_plugin_dependency_status(){
  _m=$1; _deps=$(v112_meta_get "$_m" dependencies); _missing=
  _oldifs=$IFS; IFS=,
  for _d in $_deps; do IFS=$_oldifs; _d=$(v112_trim "$_d"); [ -n "$_d" ] || { IFS=,; continue; }; grep -q "^$_d$(printf '\t')" "$V112_INDEX" 2>/dev/null || _missing="${_missing}${_missing:+,}$_d"; IFS=,; done
  IFS=$_oldifs; printf '%s\n' "$_missing"
}
v112_plugin_install_dir(){
  _src=$1; _m=$(v112_plugin_manifest "$_src"); v112_plugin_validate "$_m" >/dev/null || return 1
  _id=$(v112_meta_get "$_m" id); mkdir -p "$V112_PLUGIN_ROOT" || return 1
  rm -rf "$V112_PLUGIN_ROOT/$_id"; mkdir -p "$V112_PLUGIN_ROOT/$_id" || return 1
  cp -R "$_src"/. "$V112_PLUGIN_ROOT/$_id"/ || return 1
  v112_plugin_enable "$_id"; v112_plugin_scan
}
v112_plugin_remove(){ rm -rf "$V112_PLUGIN_ROOT/$1"; v112_plugin_enable "$1"; v112_plugin_scan; }
v112_plugin_create(){
  _id=$1 _dest=$2 _name=${3:-$1} _author=${4:-unknown}; v112_valid_id "$_id" || return 1
  [ ! -e "$_dest" ] || return 2; mkdir -p "$_dest" || return 1
  cat >"$_dest/plugin.yaml" <<EOT
id: $_id
name: $_name
version: 0.1.0
author: $_author
category: Utilities
entry: plugin.sh
min_core_version: 11.2.0
dependencies:
hooks: startup,pre-build,post-build
capabilities:
description: Generated iSH-AOK plugin.
EOT
  cat >"$_dest/plugin.sh" <<'EOT'
#!/bin/sh
# Generated iSH-AOK plugin entry point.
plugin_startup(){ :; }
plugin_pre_build(){ :; }
plugin_post_build(){ :; }
EOT
  chmod +x "$_dest/plugin.sh"
  cat >"$_dest/README.md" <<EOT
# $_name

Generated by the iSH-AOK Config v11.2 Plugin SDK.
EOT
}
v112_distribution_validate(){
  _d=$1; [ -d "$_d" ] || { echo 'missing distribution directory'; return 1; }
  _m=$_d/metadata.conf; [ -r "$_m" ] || { echo 'missing metadata.conf'; return 2; }
  for _k in id name package_manager backend architectures; do [ -n "$(v112_meta_get "$_m" "$_k")" ] || { echo "missing $_k"; return 3; }; done
  [ -r "$_d/backend.sh" ] || { echo 'missing backend.sh'; return 4; }
  sh -n "$_d/backend.sh" || { echo 'backend syntax failure'; return 5; }
  for _fn in backend_prepare backend_bootstrap backend_install_packages backend_verify backend_cleanup; do grep -Eq "^$_fn[[:space:]]*\(\)" "$_d/backend.sh" || { echo "missing function $_fn"; return 6; }; done
  [ -r "$_d/repositories.conf" ] || { echo 'missing repositories.conf'; return 7; }
  [ -r "$_d/keyrings.conf" ] || { echo 'missing keyrings.conf'; return 8; }
  echo 'valid'
}
v112_distribution_create(){
  _id=$1 _dest=$2 _pm=$3 _backend=$4 _arches=$5; v112_valid_id "$_id" || return 1
  [ ! -e "$_dest" ] || return 2; mkdir -p "$_dest" || return 1
  cat >"$_dest/metadata.conf" <<EOT
id=$_id
name=$_id
package_manager=$_pm
backend=$_backend
architectures=$_arches
default_shell=/bin/sh
default_init=sysvinit
EOT
  cat >"$_dest/repositories.conf" <<'EOT'
mirror=
release=
components=main
EOT
  cat >"$_dest/keyrings.conf" <<'EOT'
package=
path=
url=
EOT
  cat >"$_dest/packages.conf" <<'EOT'
base=sh,coreutils,ca-certificates
EOT
  cat >"$_dest/backend.sh" <<'EOT'
#!/bin/sh
backend_prepare(){ :; }
backend_bootstrap(){ echo 'Implement backend_bootstrap' >&2; return 1; }
backend_install_packages(){ :; }
backend_verify(){ :; }
backend_cleanup(){ :; }
EOT
  chmod +x "$_dest/backend.sh"
  cat >"$_dest/validation.sh" <<'EOT'
#!/bin/sh
validate_distribution_rootfs(){ [ -d "$1/etc" ]; }
EOT
  chmod +x "$_dest/validation.sh"
}
v112_catalog_report(){
  printf '%-20s %-10s %-14s %s\n' ID VERSION CATEGORY DESCRIPTION
  for _f in "$V112_CATALOG_DIR"/*.plugin; do [ -r "$_f" ] || continue; printf '%-20s %-10s %-14s %s\n' "$(v112_meta_get "$_f" id)" "$(v112_meta_get "$_f" version)" "$(v112_meta_get "$_f" category)" "$(v112_meta_get "$_f" description)"; done
}

v112_plugin_source_all(){
  v112_plugin_scan
  while IFS="$(printf '\t')" read -r _id _title _ver _cat _status _deps _m; do
    [ "$_status" = enabled ] || continue
    _entry=$(v112_meta_get "$_m" entry); _file=$(dirname "$_m")/$_entry
    [ -r "$_file" ] && . "$_file"
  done <"$V112_INDEX"
}
v112_plugin_run_hook(){
  _hook=$1; shift
  _fn=plugin_$(printf '%s' "$_hook" | tr '-' '_')
  command -v "$_fn" >/dev/null 2>&1 && "$_fn" "$@" || return 0
  return 0
}

# Non-interactive SDK health check used by diagnostics and release validation.
v112_sdk_self_test(){
  _rc=0
  _list=${TMPDIR:-/tmp}/ish-aok-sdk-self-test.$$
  : >"$_list" || return 1
  for _base in "$ISH_AOK_CONFIG_ROOT/plugins" "$V112_PLUGIN_ROOT"; do
    [ -d "$_base" ] || continue
    find "$_base" -mindepth 1 -maxdepth 3 -type f \
      \( -name plugin.yaml -o -name plugin.conf \) 2>/dev/null >>"$_list"
  done
  sort -u "$_list" -o "$_list" 2>/dev/null || true
  while IFS= read -r _manifest; do
    [ -n "$_manifest" ] || continue
    _id=$(v112_meta_get "$_manifest" id)
    [ -n "$_id" ] || _id=$(basename "$(dirname "$_manifest")")
    if v112_plugin_validate "$_manifest" >/dev/null 2>&1; then
      printf 'PASS plugin %s\n' "$_id"
    else
      printf 'FAIL plugin %s\n' "$_id"
      _rc=1
    fi
  done <"$_list"
  rm -f "$_list"
  if v112_plugin_scan >/dev/null 2>&1; then
    printf 'PASS plugin scan\n'
  else
    printf 'FAIL plugin scan\n'
    _rc=1
  fi
  return "$_rc"
}
