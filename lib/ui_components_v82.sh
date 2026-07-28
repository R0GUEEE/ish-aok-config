#!/bin/sh
# Shared UI helpers (v8.2)
ui_status_card(){ title=$1; shift; ui_text "$title" "$*"; }
ui_searchable_menu(){ title=$1; prompt=$2; shift 2; ui_menu "$title" "$prompt" "$@"; }
ui_multiselect(){ title=$1; prompt=$2; shift 2; ui_checklist "$title" "$prompt" "$@"; }
ui_confirm_action(){ ui_yesno "$1" "$2"; }
ui_table(){ title=$1; data=$2; ui_text "$title" "$data"; }
ui_progress_task(){ title=$1; shift; progress_run "$title" "$@"; }
