#!/bin/sh
# Transaction, lock, and integrity helpers for iSH-AOK Config v8.3.
V83_STATE_DIR=${V83_STATE_DIR:-$STATE_DIR/operations-v83}
V83_TX_DIR=$V83_STATE_DIR/transactions
V83_LOCK_DIR=$V83_STATE_DIR/locks
V83_BASELINE_DIR=$V83_STATE_DIR/baselines
mkdir -p "$V83_TX_DIR" "$V83_LOCK_DIR" "$V83_BASELINE_DIR" 2>/dev/null || true

v83_safe_id(){ printf '%s' "$1" | sed 's/[^A-Za-z0-9_.-]/_/g'; }
v83_now(){ date +%Y%m%d-%H%M%S; }

rootfs_lock_acquire(){
  root=${1:-$(active_rootfs)}; purpose=${2:-operation}; timeout=${3:-30}
  [ -n "$root" ] || return 2
  key=$(printf '%s' "$root" | cksum | awk '{print $1}')
  lock="$V83_LOCK_DIR/$key.lock"
  waited=0
  while ! mkdir "$lock" 2>/dev/null; do
    [ -f "$lock/pid" ] && pid=$(cat "$lock/pid" 2>/dev/null) || pid=
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$lock"; continue; fi
    [ "$waited" -ge "$timeout" ] && return 1
    sleep 1; waited=$((waited + 1))
  done
  printf '%s\n' "$$" >"$lock/pid"
  printf '%s\n' "$root" >"$lock/rootfs"
  printf '%s\n' "$purpose" >"$lock/purpose"
  printf '%s\n' "$(date +%s)" >"$lock/started"
  V83_ACTIVE_LOCK=$lock; export V83_ACTIVE_LOCK
}
rootfs_lock_release(){ [ -n "${V83_ACTIVE_LOCK:-}" ] && rm -rf "$V83_ACTIVE_LOCK" 2>/dev/null || true; V83_ACTIVE_LOCK=; export V83_ACTIVE_LOCK; }
rootfs_lock_report(){
  found=no
  for d in "$V83_LOCK_DIR"/*.lock; do [ -d "$d" ] || continue; found=yes; printf '%s\t%s\t%s\t%s\n' "$(basename "$d")" "$(cat "$d/rootfs" 2>/dev/null)" "$(cat "$d/purpose" 2>/dev/null)" "$(cat "$d/pid" 2>/dev/null)"; done
  [ "$found" = yes ] || echo 'No active RootFS locks.'
}
rootfs_lock_cleanup_stale(){
  for d in "$V83_LOCK_DIR"/*.lock; do [ -d "$d" ] || continue; pid=$(cat "$d/pid" 2>/dev/null); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && continue; rm -rf "$d"; done
}

transaction_begin(){
  name=$(v83_safe_id "${1:-transaction}"); root=${2:-$(active_rootfs)}
  id="$(v83_now)-$$-$name"; dir="$V83_TX_DIR/$id"; mkdir -p "$dir/backup" || return 1
  { printf 'id\t%s\n' "$id"; printf 'name\t%s\n' "$name"; printf 'rootfs\t%s\n' "$root"; printf 'status\topen\n'; printf 'started\t%s\n' "$(date +%s)"; } >"$dir/meta.tsv"
  : >"$dir/journal.tsv"; V83_TRANSACTION_DIR=$dir; export V83_TRANSACTION_DIR; printf '%s\n' "$id"
}
transaction_backup_path(){
  src=$1; [ -n "${V83_TRANSACTION_DIR:-}" ] || return 2
  [ -e "$src" ] || [ -L "$src" ] || { printf 'missing\t%s\t-\n' "$src" >>"$V83_TRANSACTION_DIR/journal.tsv"; return 0; }
  key=$(printf '%s' "$src" | cksum | awk '{print $1}'); dst="$V83_TRANSACTION_DIR/backup/$key"
  cp -a "$src" "$dst" || return 1
  printf 'restore\t%s\t%s\n' "$src" "$dst" >>"$V83_TRANSACTION_DIR/journal.tsv"
}
transaction_record_command(){ [ -n "${V83_TRANSACTION_DIR:-}" ] || return 2; printf 'command\t%s\t%s\n' "$(date +%s)" "$*" >>"$V83_TRANSACTION_DIR/journal.tsv"; }
transaction_commit(){ [ -n "${V83_TRANSACTION_DIR:-}" ] || return 2; sed 's/^status\topen$/status\tcommitted/' "$V83_TRANSACTION_DIR/meta.tsv" >"$V83_TRANSACTION_DIR/meta.new" && mv "$V83_TRANSACTION_DIR/meta.new" "$V83_TRANSACTION_DIR/meta.tsv"; printf 'finished\t%s\n' "$(date +%s)" >>"$V83_TRANSACTION_DIR/meta.tsv"; }
transaction_rollback_dir(){
  dir=$1; [ -f "$dir/journal.tsv" ] || return 1
  awk -F '\t' '$1=="restore"{print $2 "\t" $3}' "$dir/journal.tsv" | while IFS="$(printf '\t')" read -r dst src; do [ -e "$src" ] || continue; rm -rf "$dst"; cp -a "$src" "$dst" || exit 1; done || return 1
  sed 's/^status\t[a-z]*$/status\trolled-back/' "$dir/meta.tsv" >"$dir/meta.new" && mv "$dir/meta.new" "$dir/meta.tsv"
}
transaction_rollback(){ transaction_rollback_dir "${1:-${V83_TRANSACTION_DIR:-}}"; }
transaction_list(){ for d in "$V83_TX_DIR"/*; do [ -d "$d" ] || continue; id=$(basename "$d"); name=$(awk -F '\t' '$1=="name"{print $2}' "$d/meta.tsv"); status=$(awk -F '\t' '$1=="status"{print $2}' "$d/meta.tsv"); root=$(awk -F '\t' '$1=="rootfs"{print $2}' "$d/meta.tsv"); printf '%s\t%s\t%s\t%s\n' "$id" "$status" "$name" "$root"; done; }

integrity_hash_command(){ command -v sha256sum >/dev/null 2>&1 && echo sha256sum || { command -v shasum >/dev/null 2>&1 && echo 'shasum -a 256' || echo cksum; }; }
integrity_create_baseline(){
  root=${1:-$(active_rootfs)}; name=$(v83_safe_id "${2:-default}"); [ -d "$root" ] || return 2
  out="$V83_BASELINE_DIR/$name.tsv"; cmd=$(integrity_hash_command)
  { printf '# rootfs\t%s\n' "$root"; printf '# created\t%s\n' "$(date +%s)"; find "$root/etc" "$root/bin" "$root/sbin" -type f 2>/dev/null | sort | while IFS= read -r f; do sum=$(sh -c "$cmd \"\$1\"" sh "$f" 2>/dev/null | awk '{print $1}'); printf '%s\t%s\n' "$sum" "${f#$root}"; done; } >"$out"
  printf '%s\n' "$out"
}
integrity_verify_baseline(){
  file=$1; [ -f "$file" ] || return 2; root=$(sed -n 's/^# rootfs\t//p' "$file" | head -n1); cmd=$(integrity_hash_command); rc=0
  while IFS="$(printf '\t')" read -r expected rel; do case $expected in \#*|'') continue;; esac; f="$root$rel"; if [ ! -f "$f" ]; then printf 'MISSING\t%s\n' "$rel"; rc=1; continue; fi; actual=$(sh -c "$cmd \"\$1\"" sh "$f" 2>/dev/null | awk '{print $1}'); [ "$actual" = "$expected" ] || { printf 'CHANGED\t%s\n' "$rel"; rc=1; }; done <"$file"
  return $rc
}
integrity_list_baselines(){ for f in "$V83_BASELINE_DIR"/*.tsv; do [ -f "$f" ] && printf '%s\n' "$f"; done; }

cache_invalidate_prefix(){ prefix=$1; [ -d "$V82_CACHE_DIR" ] || return 0; for f in "$V82_CACHE_DIR"/*.cache; do [ -f "$f" ] || continue; grep -q "^key=$prefix" "$f" 2>/dev/null && rm -f "$f"; done; }
