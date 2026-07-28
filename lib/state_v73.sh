#!/bin/sh

V73_STATE_DIR=${V73_STATE_DIR:-$STATE_DIR/workspace}
V73_ACTIVITY_FILE=$V73_STATE_DIR/activity.tsv
V73_NOTIFICATION_FILE=$V73_STATE_DIR/notifications.tsv
V73_FAVORITES_FILE=$V73_STATE_DIR/favorites.tsv
V73_RECENT_ACTIONS_FILE=$V73_STATE_DIR/recent-actions.tsv
V73_SESSION_FILE=$V73_STATE_DIR/session.conf
V73_EVENTS_DIR=$V73_STATE_DIR/events
mkdir -p "$V73_STATE_DIR" "$V73_EVENTS_DIR" 2>/dev/null || true
for f in "$V73_ACTIVITY_FILE" "$V73_NOTIFICATION_FILE" "$V73_FAVORITES_FILE" "$V73_RECENT_ACTIONS_FILE"; do [ -f "$f" ] || : >"$f"; done

v73_now(){ date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date; }
v73_clean_field(){ printf '%s' "$*" | tr '\t\r\n' '   '; }

activity_add(){
  kind=$(v73_clean_field "${1:-action}"); shift 2>/dev/null || true
  text=$(v73_clean_field "$*")
  printf '%s\t%s\t%s\n' "$(v73_now)" "$kind" "$text" >>"$V73_ACTIVITY_FILE"
  tail -n 250 "$V73_ACTIVITY_FILE" >"$V73_ACTIVITY_FILE.tmp" 2>/dev/null && mv "$V73_ACTIVITY_FILE.tmp" "$V73_ACTIVITY_FILE"
}

recent_action_add(){
  id=$(v73_clean_field "$1"); title=$(v73_clean_field "$2")
  awk -F '\t' -v id="$id" '$2!=id{print}' "$V73_RECENT_ACTIONS_FILE" >"$V73_RECENT_ACTIONS_FILE.tmp" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$(v73_now)" "$id" "$title" >>"$V73_RECENT_ACTIONS_FILE.tmp"
  tail -n 25 "$V73_RECENT_ACTIONS_FILE.tmp" >"$V73_RECENT_ACTIONS_FILE"
  rm -f "$V73_RECENT_ACTIONS_FILE.tmp"
}

notification_add(){
  level=$(v73_clean_field "${1:-info}"); shift 2>/dev/null || true
  text=$(v73_clean_field "$*")
  id=$(date +%s 2>/dev/null || echo $$)-$$
  printf '%s\t%s\t%s\t%s\tunread\n' "$id" "$(v73_now)" "$level" "$text" >>"$V73_NOTIFICATION_FILE"
}

notification_unread_count(){ awk -F '\t' '$5=="unread"{n++} END{print n+0}' "$V73_NOTIFICATION_FILE" 2>/dev/null; }
notification_mark_all_read(){ awk -F '\t' 'BEGIN{OFS="\t"}{$5="read";print}' "$V73_NOTIFICATION_FILE" >"$V73_NOTIFICATION_FILE.tmp" && mv "$V73_NOTIFICATION_FILE.tmp" "$V73_NOTIFICATION_FILE"; }
notification_clear(){ : >"$V73_NOTIFICATION_FILE"; }

favorite_has(){ grep -Fqx "$1" "$V73_FAVORITES_FILE" 2>/dev/null; }
favorite_add(){ favorite_has "$1" || printf '%s\n' "$1" >>"$V73_FAVORITES_FILE"; }
favorite_remove(){ grep -Fvx "$1" "$V73_FAVORITES_FILE" >"$V73_FAVORITES_FILE.tmp" 2>/dev/null || true; mv "$V73_FAVORITES_FILE.tmp" "$V73_FAVORITES_FILE"; }
favorite_toggle(){ favorite_has "$1" && favorite_remove "$1" || favorite_add "$1"; }

session_save(){
  key=$(v73_clean_field "$1"); value=$(v73_clean_field "$2")
  [ -f "$V73_SESSION_FILE" ] || : >"$V73_SESSION_FILE"
  awk -F '=' -v k="$key" '$1!=k{print}' "$V73_SESSION_FILE" >"$V73_SESSION_FILE.tmp" 2>/dev/null || true
  printf '%s=%s\n' "$key" "$value" >>"$V73_SESSION_FILE.tmp"
  mv "$V73_SESSION_FILE.tmp" "$V73_SESSION_FILE"
}
session_get(){ awk -F '=' -v k="$1" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$V73_SESSION_FILE" 2>/dev/null; }
session_clear(){ : >"$V73_SESSION_FILE"; }

event_emit(){
  name=$(v73_clean_field "$1"); shift
  payload=$(v73_clean_field "$*")
  printf '%s\t%s\n' "$(v73_now)" "$payload" >>"$V73_EVENTS_DIR/$name.log"
  hooks="$V73_STATE_DIR/hooks/$name.d"
  [ -d "$hooks" ] || return 0
  for h in "$hooks"/*; do [ -x "$h" ] && "$h" "$payload" >/dev/null 2>&1 || true; done
}
