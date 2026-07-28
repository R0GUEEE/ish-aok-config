#!/bin/sh
V93_PATH_STATE=${V93_PATH_STATE:-$STATE_DIR/build-paths-v93}
V93_RECENT_SOURCES=${V93_RECENT_SOURCES:-$V93_PATH_STATE/recent-sources.tsv}
V93_RECENT_ARTIFACTS=${V93_RECENT_ARTIFACTS:-$V93_PATH_STATE/recent-artifacts.tsv}
mkdir -p "$V93_PATH_STATE" 2>/dev/null || true

v93_abs_path(){ case ${1:-} in /*) return 0;; *) return 1;; esac; }
v93_safe_output_dir(){
  p=${1:-}; v93_abs_path "$p" || return 1
  case $p in /|/AOK|/opt/AOK|/root|/home|/usr|/var|/etc|/bin|/sbin|/lib|/lib64) return 1;; esac
  case $p in *'/../'*|*/..|*'/./'*|*/.) return 1;; esac
  return 0
}
v93_remember(){ file=$1; value=$2; [ -n "$value" ] || return 0; mkdir -p "$V93_PATH_STATE"; t="$file.tmp.$$"; { printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date)" "$value"; awk -F '\t' -v p="$value" '$2!=p{print}' "$file" 2>/dev/null | head -n 19; } >"$t" && mv "$t" "$file"; }
v93_recent_values(){ awk -F '\t' 'NF>1{print $2}' "$1" 2>/dev/null; }

v93_source_type_validate(){ case ${1:-repository} in repository|archive|directory|native) return 0;; *) return 1;; esac; }
v93_source_validate(){
  type=${1:-repository}; value=${2:-}
  v93_source_type_validate "$type" || { printf 'Unsupported source type: %s\n' "$type"; return 1; }
  case $type in
    repository) [ -z "$value" ] || case $value in http://*|https://*|ftp://*|file://*|/*) :;; *) printf 'Repository source must be a URL or absolute path.\n'; return 1;; esac;;
    archive) [ -n "$value" ] && { case $value in http://*|https://*|ftp://*|file://*|/*) :;; *) printf 'Archive source must be a URL or absolute path.\n'; return 1;; esac; } || { printf 'Archive source is required.\n'; return 1; };;
    directory) v93_abs_path "$value" || { printf 'Directory source must be an absolute path.\n'; return 1; };;
    native) :;;
  esac
}

v93_artifact_default(){ printf '%s/build-artifacts\n' "${AOK_ROOT:-/AOK}"; }
v93_artifact_validate(){
  p=${1:-}; v93_safe_output_dir "$p" || { printf 'Unsafe artifact directory: %s\n' "$p"; return 1; }
  parent=$(dirname "$p"); while [ ! -e "$parent" ] && [ "$parent" != / ]; do parent=$(dirname "$parent"); done
  [ -d "$parent" ] && { [ -w "$parent" ] || is_root || have sudo || have doas; } || { printf 'Artifact parent is not writable: %s\n' "$parent"; return 1; }
}

v93_select_recent(){ file=$1; title=$2; set --; while IFS= read -r p; do [ -n "$p" ] && set -- "$@" "$p" "$p"; done <<EOF_RECENT
$(v93_recent_values "$file")
EOF_RECENT
  [ "$#" -gt 0 ] || { ui_msg "$title" 'No recent entries are recorded.'; return 1; }
  ui_menu "$title" 'Select a recent value.' "$@"
}

v93_source_select(){
  cur_type=${1:-repository}; cur_value=${2:-};
  type=$(ui_radiolist 'Build source type' 'Choose where bootstrap content comes from.' repository 'Distribution repository or mirror' "$(v87_choice_state "$cur_type" repository)" archive 'Local or remote rootfs/stage archive' "$(v87_choice_state "$cur_type" archive)" directory 'Existing directory tree' "$(v87_choice_state "$cur_type" directory)" native 'Native builder defaults' "$(v87_choice_state "$cur_type" native)") || return
  case $type in
    repository) value=$(ui_input 'Build source' 'Mirror URL or absolute repository path; blank uses backend defaults' "$cur_value") || return;;
    archive) value=$(ui_input 'Build source' 'Archive URL or absolute archive path' "$cur_value") || return;;
    directory) value=$(ui_input 'Build source' 'Absolute source directory' "$cur_value") || return;;
    native) value='';;
  esac
  msg=$(v93_source_validate "$type" "$value" 2>&1) || { ui_msg 'Build source' "$msg"; return 1; }
  [ -n "$value" ] && v93_remember "$V93_RECENT_SOURCES" "$value"
  printf '%s|%s\n' "$type" "$value"
}

v93_artifact_select(){
  suggested=${1:-$(v93_artifact_default)}
  while :; do
    c=$(ui_menu 'Build artifact location' "Suggested: $suggested" suggested 'Use suggested artifact directory' state 'Use project state artifacts directory' aok 'Use /AOK/build-artifacts' recent 'Choose recent artifact directory' custom 'Enter custom absolute directory') || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$_menu_rc"; };
    case $c in suggested) p=$suggested;; state) p="$STATE_DIR/artifacts";; aok) p=/AOK/build-artifacts;; recent) p=$(v93_select_recent "$V93_RECENT_ARTIFACTS" 'Recent artifact directories') || continue;; custom) p=$(ui_input 'Artifact directory' 'Absolute output directory' "$suggested") || continue;; esac
    msg=$(v93_artifact_validate "$p" 2>&1) || { ui_msg 'Artifact directory' "$msg"; continue; }
    v93_remember "$V93_RECENT_ARTIFACTS" "$p"; printf '%s\n' "$p"; return 0
  done
}

v93_build_paths_report(){
  printf 'iSH-AOK Config 9.3.0 — Build Sources and Artifacts\n\n'
  printf 'Source type: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_TYPE)"
  printf 'Source value: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" SOURCE_VALUE)"
  printf 'RootFS destination: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" DEST)"
  printf 'Artifact directory: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" ARTIFACT_DIR)"
  printf 'Compression: %s\n' "$(v87_profile_get "$V87_BUILD_PROFILE" COMPRESSION)"
}
