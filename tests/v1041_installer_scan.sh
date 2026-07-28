#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh -n "$BASE/install.sh"
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
grep -q 'detect_system()' "$BASE/install.sh"
grep -q 'scan_dependencies()' "$BASE/install.sh"
for pm in apt-get apk pacman dnf xbps-install emerge; do
    grep -q "$pm" "$BASE/install.sh"
done
for option in --check --dry-run --skip-deps --with-builders --interactive --prefix; do
    "$BASE/install.sh" --help | grep -q -- "$option"
done
TMP=${TMPDIR:-/tmp}/ish-aok-installer-test.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/root"
DESTDIR="$TMP/root" "$BASE/install.sh" --skip-deps --prefix /usr >/dev/null
[ -x "$TMP/root/usr/bin/ish-aok-config" ]
[ -x "$TMP/root/usr/lib/ish-aok-config/ish-aok-config" ]
"$BASE/install.sh" --dry-run --skip-deps --prefix "$TMP/prefix" | grep -q 'create launcher'
printf 'v10.6.0 installer scanner: PASS\n'
