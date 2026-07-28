#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
for f in lib/operations_v83.sh modules/operations_v83.sh; do [ -s "$BASE/$f" ]; sh -n "$BASE/$f"; done
grep -q 'v83_operations_menu' "$BASE/modules/main.sh"
grep -q "command_register operations" "$BASE/lib/dispatcher_v73.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
STATE_DIR=$TMP/state; V83_STATE_DIR=$STATE_DIR/operations-v83; V83_TX_DIR=$V83_STATE_DIR/transactions; V83_LOCK_DIR=$V83_STATE_DIR/locks; V83_BASELINE_DIR=$V83_STATE_DIR/baselines; mkdir -p "$V83_TX_DIR" "$V83_LOCK_DIR" "$V83_BASELINE_DIR"
. "$BASE/lib/operations_v83.sh"
mkdir -p "$TMP/root/etc" "$TMP/root/bin" "$TMP/root/sbin"; echo before >"$TMP/root/etc/test.conf"
transaction_begin test "$TMP/root" >/dev/null
transaction_backup_path "$TMP/root/etc/test.conf"
echo after >"$TMP/root/etc/test.conf"
transaction_commit
transaction_rollback_dir "$V83_TRANSACTION_DIR"
grep -q before "$TMP/root/etc/test.conf"
rootfs_lock_acquire "$TMP/root" test 1
[ -d "$V83_ACTIVE_LOCK" ]
rootfs_lock_release
[ ! -d "${V83_ACTIVE_LOCK:-/nonexistent}" ]
echo 'v8.3 operations tests passed'
