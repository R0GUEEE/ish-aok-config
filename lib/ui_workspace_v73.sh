#!/bin/sh

V73_UI_MODE_FILE=${V73_UI_MODE_FILE:-$V73_STATE_DIR/ui-mode}
V73_UI_MODE=${V73_UI_MODE:-$(cat "$V73_UI_MODE_FILE" 2>/dev/null || printf '%s' compact)}
case $V73_UI_MODE in compact|full) :;; *) V73_UI_MODE=compact;; esac

ui_mode_get(){ printf '%s' "$V73_UI_MODE"; }
ui_mode_set(){
  case $1 in compact|full) V73_UI_MODE=$1; printf '%s\n' "$1" >"$V73_UI_MODE_FILE";; *) return 1;; esac
}

ui_terminal_size(){
  rows=$(tput lines 2>/dev/null || printf '24')
  cols=$(tput cols 2>/dev/null || printf '80')
  case $rows in ''|*[!0-9]*) rows=24;; esac
  case $cols in ''|*[!0-9]*) cols=80;; esac
  printf '%s %s\n' "$rows" "$cols"
}

ui_status_line(){
  label=$1; value=$2; state=${3:-info}
  case $state in ok) mark='[OK]' ;; warn) mark='[!]' ;; error) mark='[X]' ;; *) mark='[-]' ;; esac
  printf '%-4s %-18s %s\n' "$mark" "$label" "$value"
}

ui_breadcrumb(){
  [ -n "${V73_BREADCRUMB:-}" ] && printf '%s\n\n' "$V73_BREADCRUMB"
}

ui_mode_menu(){
  current=$(ui_mode_get)
  c=$(ui_radiolist 'Interface mode' 'Compact shows common actions. Full shows status and management actions.' \
    compact 'Compact interface' "$([ "$current" = compact ] && echo on || echo off)" \
    full 'Full interface' "$([ "$current" = full ] && echo on || echo off)") || return
  ui_mode_set "$c"
  session_save ui_mode "$c"
  activity_add workspace "Changed interface mode to $c"
}
