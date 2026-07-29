#!/bin/sh
PROGRAM='iSH-AOK Config'
VERSION='11.3.2'
BACKTITLE='Portable system configuration for iSH-AOK root filesystems'
STATE_DIR=${XDG_STATE_HOME:-${HOME:-/root}/.local/state}/ish-aok-config
BACKUP_DIR=$STATE_DIR/backups
REPORT_DIR=$STATE_DIR/reports
LOG_FILE=$STATE_DIR/ish-aok-config.log
TMP_DIR=${TMPDIR:-/tmp}/ish-aok-config.$$
CURRENT_HOME=${HOME:-/root}
CURRENT_USER=$(id -un 2>/dev/null || printf '%s' "${USER:-root}")
UI=text
DISTRO_ID=unknown
DISTRO_LIKE=''
PKG_MGR=unknown
INIT_SYSTEM=unknown
ARCH=$(uname -m 2>/dev/null || echo unknown)
AOK_DETECTED=no
VERBOSE=${ISH_AOK_VERBOSE:-yes}
DEBUG=${ISH_AOK_DEBUG:-no}
DRY_RUN=${ISH_AOK_DRY_RUN:-no}
mkdir -p "$STATE_DIR" "$BACKUP_DIR" "$REPORT_DIR" "$TMP_DIR" 2>/dev/null || true
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
log(){ printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)" "$*" >>"$LOG_FILE"; [ "$DEBUG" = yes ] && printf '[debug] %s\n' "$*" >&2 || true; }
verbose(){ [ "$VERBOSE" = yes ] && printf '[ish-aok-config] %s\n' "$*" >&2 || true; }
quote_cmd(){ out=''; for arg in "$@"; do q=$(printf '%s' "$arg" | sed "s/'/'\\''/g"); out="$out '$q'"; done; printf '%s' "${out# }"; }
run_cmd(){ verbose "Running: $(quote_cmd "$@")"; log "RUN $(quote_cmd "$@")"; [ "$DRY_RUN" = yes ] && return 0; "$@"; rc=$?; log "EXIT $rc $(quote_cmd "$@")"; return $rc; }
run_root(){ if is_root; then run_cmd "$@"; elif have doas; then run_cmd doas "$@"; elif have sudo; then run_cmd sudo "$@"; else return 126; fi; }
have(){ command -v "$1" >/dev/null 2>&1; }
is_root(){ [ "$(id -u)" -eq 0 ]; }
as_root(){ run_root "$@"; }
need_root(){ is_root || have doas || have sudo || { ui_msg Error 'This action needs root, sudo, or doas.'; return 1; }; }
# Namespaced locals: POSIX sh has no scoping, and plain s/n leaked into callers.
backup_file(){ _bk_f=$1; [ -e "$_bk_f" ] || return 0; _bk_s=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now); _bk_n=$(printf %s "$_bk_f"|sed 's#^/##;s#/#_#g'); cp -p "$_bk_f" "$BACKUP_DIR/$_bk_n.$_bk_s" 2>/dev/null || as_root cp -p "$_bk_f" "$BACKUP_DIR/$_bk_n.$_bk_s"; }
write_file(){ f=$1; mode=${2:-644}; data=$3; d=$(dirname "$f"); [ -d "$d" ] || { mkdir -p "$d" 2>/dev/null || as_root mkdir -p "$d"; }; backup_file "$f"; t=$TMP_DIR/write; printf '%b\n' "$data" >"$t"; if [ -w "$d" ] || [ -w "$f" ]; then cp "$t" "$f" && chmod "$mode" "$f"; else as_root cp "$t" "$f" && as_root chmod "$mode" "$f"; fi; }
append_unique(){ f=$1; line=$2; [ -e "$f" ] || write_file "$f" 644 ''; grep -Fqx "$line" "$f" 2>/dev/null && return; backup_file "$f"; if [ -w "$f" ]; then printf '%s\n' "$line" >>"$f"; else printf '%s\n' "$line"|as_root tee -a "$f" >/dev/null; fi; }
replace_block(){ f=$1; name=$2; body=$3; b="# >>> ish-aok-config: $name >>>"; e="# <<< ish-aok-config: $name <<<"; t=$TMP_DIR/block; [ -f "$f" ] && awk -v b="$b" -v e="$e" '$0==b{s=1;next}$0==e{s=0;next}!s{print}' "$f" >"$t" || : >"$t"; { cat "$t"; printf '\n%s\n%b\n%s\n' "$b" "$body" "$e"; } >"$t.new"; write_file "$f" 644 "$(cat "$t.new")"; }
edit_file(){ f=$1; d=$(dirname "$f"); [ -d "$d" ] || mkdir -p "$d" 2>/dev/null || as_root mkdir -p "$d"; [ -e "$f" ] || write_file "$f" 644 ''; ed=${VISUAL:-${EDITOR:-}}; for e in "$ed" nano nvim vim vi micro; do [ -n "$e" ] && have "${e%% *}" && { ed=$e; break; }; done; [ -n "$ed" ] || { ui_msg Editor 'No editor installed.'; return; }; backup_file "$f"; [ -w "$f" ] && sh -c "$ed \"$f\"" || as_root sh -c "$ed \"$f\""; }
run_capture(){ title=$1; shift; progress_run "$title" "$@"; rc=$?; progress_summary "$title" "$rc" "$PROGRESS_LAST_LOG"; return "$rc"; }
settings_save(){ mkdir -p "$STATE_DIR"; { printf 'VERBOSE=%s\n' "$VERBOSE"; printf 'DEBUG=%s\n' "$DEBUG"; printf 'DRY_RUN=%s\n' "$DRY_RUN"; printf 'PROGRESS_ENABLED=%s\n' "${PROGRESS_ENABLED:-yes}"; } >"$STATE_DIR/settings"; }
settings_load(){ [ -r "$STATE_DIR/settings" ] && . "$STATE_DIR/settings" || true; export VERBOSE DEBUG DRY_RUN; }
