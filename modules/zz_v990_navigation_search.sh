#!/bin/sh
# v9.9 global navigation search, usage ranking and index diagnostics.

V990_NAV_DIR=${V990_NAV_DIR:-$STATE_DIR/navigation-v990}
V990_INDEX=${V990_INDEX:-$V990_NAV_DIR/search-index.tsv}
V990_USAGE=${V990_USAGE:-$V990_NAV_DIR/usage.tsv}
V990_REPORT=${V990_REPORT:-$REPORT_DIR/navigation-search-v990.txt}
mkdir -p "$V990_NAV_DIR" 2>/dev/null || true
[ -e "$V990_USAGE" ] || : >"$V990_USAGE"

v990_clean_field(){ printf '%s' "$1" | tr '\t\r\n|' '    '; }

v990_index_build(){
  tmp=$V990_INDEX.$$
  : >"$tmp"
  for file in "$V91_MENU_DIR"/*.menu; do
    [ -f "$file" ] || continue
    menu=${file##*/}; menu=${menu%.menu}
    while IFS='|' read -r id label handler description; do
      case $id in ''|'#'*) continue;; esac
      case $handler in
        @menu:*) target=${handler#@menu:}; kind=menu;;
        @return) continue;;
        *) target=$handler; kind=action;;
      esac
      key="menu:$menu:$id"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(v990_clean_field "$key")" "$kind" "$(v990_clean_field "$label")" \
        "$(v990_clean_field "$(v91_menu_title "$menu")")" "$(v990_clean_field "$target")" \
        "$(v990_clean_field "$description")" >>"$tmp"
    done <"$file"
  done
  if [ -r "$V73_ACTIONS_FILE" ]; then
    while IFS="$(printf '\t')" read -r id label category handler description; do
      [ -n "$id" ] || continue
      printf '%s\tcommand\t%s\t%s\t%s\t%s\n' \
        "$(v990_clean_field "command:$id")" "$(v990_clean_field "$label")" \
        "$(v990_clean_field "$category")" "$(v990_clean_field "$id")" \
        "$(v990_clean_field "$description")" >>"$tmp"
    done <"$V73_ACTIONS_FILE"
  fi
  awk -F '\t' '!seen[$1]++' "$tmp" >"$V990_INDEX"
  rm -f "$tmp"
}

v990_usage_record(){
  key=$1
  [ -n "$key" ] || return 0
  tmp=$V990_USAGE.$$
  awk -F '\t' -v k="$key" 'BEGIN{found=0} $1==k{print $1 "\t" ($2+1) "\t" systime(); found=1; next} {print} END{if(!found) print k "\t1\t" systime()}' "$V990_USAGE" >"$tmp"
  mv "$tmp" "$V990_USAGE"
}

v990_usage_count(){ awk -F '\t' -v k="$1" '$1==k{print $2;exit}' "$V990_USAGE" 2>/dev/null; }

v990_search_rows(){
  query=$1
  [ -s "$V990_INDEX" ] || v990_index_build
  awk -F '\t' -v q="$query" 'BEGIN{q=tolower(q)} q=="" || index(tolower($0),q){print}' "$V990_INDEX"
}

v990_open_result(){
  key=$1 kind=$2 target=$3
  v990_usage_record "$key"
  case $kind in
    menu) v91_menu_run "$target";;
    command) command_run "$target";;
    action) command -v "$target" >/dev/null 2>&1 && "$target" || ui_msg Navigation "Handler is unavailable: $target";;
    *) ui_msg Navigation "Unknown result type: $kind";;
  esac
}

v990_choose_rows(){
  title=$1 prompt=$2 rows=$3
  set --
  map=$TMP_DIR/v990-map.$$
  : >"$map"
  n=0
  printf '%s\n' "$rows" | while IFS="$(printf '\t')" read -r key kind label location target description; do
    [ -n "$key" ] || continue
    count=$(v990_usage_count "$key"); count=${count:-0}
    n=$((n+1))
    printf '%s\t%s\t%s\n' "$n" "$key" "$kind" >>"$map"
    shown="$label — $location"
    [ -n "$description" ] && shown="$shown — $description"
    [ "$count" -gt 0 ] 2>/dev/null && shown="$shown [$count uses]"
    printf '%s\t%s\n' "$n" "$shown"
  done >"$map.items"
  while IFS="$(printf '\t')" read -r id shown; do set -- "$@" "$id" "$shown"; done <"$map.items"
  [ "$#" -gt 0 ] || { rm -f "$map" "$map.items"; ui_msg "$title" 'No matching menu tools were found.'; return 0; }
  choice=$(ui_menu "$title" "$prompt" "$@") || { rc=$?; rm -f "$map" "$map.items"; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc"; }
  row=$(awk -F '\t' -v n="$choice" '$1==n{print;exit}' "$map")
  rm -f "$map" "$map.items"
  key=$(printf '%s' "$row" | cut -f2); kind=$(printf '%s' "$row" | cut -f3)
  data=$(awk -F '\t' -v k="$key" '$1==k{print;exit}' "$V990_INDEX")
  target=$(printf '%s' "$data" | cut -f5)
  [ -n "$key" ] && v990_open_result "$key" "$kind" "$target"
}

v990_search_ui(){
  query=$(ui_input 'Global Menu Search' 'Search labels, descriptions, categories and handlers:' '') || return 0
  rows=$(v990_search_rows "$query")
  v990_choose_rows 'Global Menu Search' "Results for: $query" "$rows"
}

v990_most_used_ui(){
  [ -s "$V990_INDEX" ] || v990_index_build
  rows=$(awk -F '\t' 'NR==FNR{count[$1]=$2;next} count[$1]>0{print count[$1] "\t" $0}' "$V990_USAGE" "$V990_INDEX" | sort -t "$(printf '\t')" -k1,1nr | head -n 20 | cut -f2-)
  v990_choose_rows 'Most Used Tools' 'Open a frequently used menu tool.' "$rows"
}

v990_navigation_search_report(){
  v990_index_build
  menu_count=$(awk -F '\t' '$2=="menu"{n++} END{print n+0}' "$V990_INDEX")
  action_count=$(awk -F '\t' '$2=="action"{n++} END{print n+0}' "$V990_INDEX")
  command_count=$(awk -F '\t' '$2=="command"{n++} END{print n+0}' "$V990_INDEX")
  duplicate_count=$(cut -f1 "$V990_INDEX" | sort | uniq -d | wc -l | tr -d ' ')
  {
    printf '%s %s — Navigation Search Index\n\n' "$PROGRAM" "$VERSION"
    printf 'Menu jumps: %s\nDirect actions: %s\nCommand actions: %s\nDuplicate keys: %s\n' "$menu_count" "$action_count" "$command_count" "$duplicate_count"
    printf 'Index: %s\nUsage: %s\n\nTop usage:\n' "$V990_INDEX" "$V990_USAGE"
    if [ -s "$V990_USAGE" ]; then sort -t "$(printf '\t')" -k2,2nr "$V990_USAGE" | head -n 10; else printf '  (none)\n'; fi
  } >"$V990_REPORT"
  [ "$duplicate_count" -eq 0 ]
}

v990_navigation_search_report_ui(){ v990_navigation_search_report || true; ui_text 'Navigation Search Report' "$(cat "$V990_REPORT")"; }

v990_navigation_search_menu(){
  while :; do
    c=$(ui_menu 'Navigation Search' 'Find any menu tool without traversing the hierarchy.' search 'Search all tools' used 'Most used tools' rebuild 'Rebuild search index' report 'Search-index report' back 'Back') || { rc=$?; [ "$rc" -eq "${UI_MENU_BACK_RC:-90}" ] && return 0; return "$rc"; }
    case $c in
      search) v990_search_ui;;
      used) v990_most_used_ui;;
      rebuild) v990_index_build; ui_msg 'Navigation Search' 'Search index rebuilt.';;
      report) v990_navigation_search_report_ui;;
    esac
  done
}

command_registry_build(){
  command_registry_build_base
  printf '%s\t%s\t%s\t%s\t%s\n' architecture 'Developer architecture' Development v91_developer_center 'Modular menus, docs and tests' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' architecture_report 'Architecture report' Reports v91_architecture_report 'v9.1 modular-core status' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_diagnostics 'Open navigation diagnostics' Workspace v970_navigation_diagnostics_menu 'Canonical routes, audits and saved-state repair' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_history 'Open navigation history' Workspace v980_history_menu 'Breadcrumbs and recently visited canonical menus' >>"$V73_ACTIONS_FILE"
  printf '%s\t%s\t%s\t%s\t%s\n' navigation_search 'Search all menu tools' Workspace v990_navigation_search_menu 'Global menu search and most-used actions' >>"$V73_ACTIONS_FILE"
}
