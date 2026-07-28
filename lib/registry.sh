#!/bin/sh
REGISTRY_DIR=${ISH_AOK_CONFIG_ROOT:-.}/catalogs
REGISTRY_STATE_DIR=${STATE_DIR:-${HOME:-/root}/.local/state/ish-aok-config}/registry
mkdir -p "$REGISTRY_STATE_DIR" 2>/dev/null || true

registry_catalog(){ printf '%s/%s.tsv' "$REGISTRY_DIR" "$1"; }
registry_each(){
  catalog=$1; shift
  file=$(registry_catalog "$catalog")
  [ -r "$file" ] || return 0
  while IFS='|' read -r id label description handler flags; do
    case $id in ''|'#'*) continue;; esac
    "$@" "$id" "$label" "$description" "$handler" "$flags"
  done <"$file"
}
registry_menu(){
  catalog=$1 title=$2 text=$3
  file=$(registry_catalog "$catalog")
  [ -r "$file" ] || { ui_msg "$title" "Catalog not found: $file"; return 1; }
  set --
  while IFS='|' read -r id label description handler flags; do
    case $id in ''|'#'*) continue;; esac
    set -- "$@" "$id" "$label — $description"
  done <"$file"
  choice=$(ui_menu "$title" "$text" "$@") || { _menu_rc=$?; [ "$_menu_rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return 1; };
  registry_dispatch "$catalog" "$choice"
}
registry_dispatch(){
  catalog=$1 wanted=$2
  file=$(registry_catalog "$catalog")
  while IFS='|' read -r id label description handler flags; do
    [ "$id" = "$wanted" ] || continue
    if command -v "$handler" >/dev/null 2>&1; then "$handler" "$id" "$label" "$description" "$flags"; else ui_msg "$label" "Handler is not available: $handler"; fi
    return
  done <"$file"
  ui_msg Registry "Unknown catalog item: $wanted"
}
registry_report(){
  out=$REPORT_DIR/registry-report.txt
  : >"$out"
  for f in "$REGISTRY_DIR"/*.tsv; do
    [ -f "$f" ] || continue
    printf '\n[%s]\n' "$(basename "$f" .tsv)" >>"$out"
    awk -F'|' '!/^#/ && NF>=4 {printf "%-24s %-28s %s\n",$1,$2,$3}' "$f" >>"$out"
  done
  if [ "${REGISTRY_REPORT_QUIET:-no}" = yes ]; then cat "$out"; else ui_text 'Registry report' "$(cat "$out")"; fi
}
