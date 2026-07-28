#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MOD="$BASE/modules/zzzzzzzzzzzzzzzz_v111_rootfs_keyring_cache.sh"
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
grep -q 'ubuntu-keyring|usr/share/keyrings/ubuntu-archive-keyring.gpg' "$MOD"
grep -q 'binary-all/Packages.xz' "$MOD"
grep -q 'dpkg-deb -x' "$MOD"
grep -q 'SHA-256 checksum' "$MOD"
grep -q -- '--keyring="$key"' "$MOD"
sh -n "$MOD"
# Verify Packages parser with a small local fixture.
TMP=${TMPDIR:-/tmp}/v111-test.$$
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP"
cat > "$TMP/Packages" <<'PKG'
Package: other
Filename: pool/o/other.deb
SHA256: deadbeef

Package: ubuntu-keyring
Version: 2023.11.28.1
Filename: pool/main/u/ubuntu-keyring/ubuntu-keyring_2023.11.28.1_all.deb
SHA256: 0123456789abcdef

PKG
# Extract only the function needed for a direct parser test.
sed -n '/^v111_packages_record(){/,/^}/p' "$MOD" > "$TMP/parser.sh"
. "$TMP/parser.sh"
out=$(v111_packages_record ubuntu-keyring "$TMP/Packages")
[ "$out" = 'pool/main/u/ubuntu-keyring/ubuntu-keyring_2023.11.28.1_all.deb|0123456789abcdef' ]
printf 'v10.11 target keyring cache test passed\n'
