#!/bin/sh
set -u
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd)
TMP=${TMPDIR:-/tmp}/ish-aok-tests.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP"
export TERM=${TERM:-xterm}
mkdir -p "$TMP/home"

passed=0 failed=0
for test in "$BASE"/tests/*.sh "$BASE"/tests/unit/*.sh "$BASE"/tests/integration/*.sh "$BASE"/tests/regression/*.sh "$BASE"/tests/portability/*.sh; do
  [ -f "$test" ] || continue
  [ "$test" = "$BASE/tests/run-all.sh" ] && continue
  printf '%-48s' "$(basename "$test")"
  test_home="$TMP/home/$(basename "$test" .sh)"; mkdir -p "$test_home"
  if env -u XDG_STATE_HOME HOME="$test_home" TERM="$TERM" sh "$test" >"$TMP/out" 2>"$TMP/err"; then
    printf ' PASS\n'; passed=$((passed+1))
  else
    printf ' FAIL\n'; failed=$((failed+1)); cat "$TMP/out"; cat "$TMP/err" >&2
  fi
done
printf '\nPassed: %s  Failed: %s\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
