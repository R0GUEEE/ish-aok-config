#!/bin/bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../src/features/rootfs.sh
source "$PROJECT_DIR/src/features/rootfs.sh"

failures=0
checks=0

check() {
    local description="$1"
    shift
    checks=$((checks + 1))
    if "$@"; then
        printf 'ok %d - %s\n' "$checks" "$description"
    else
        printf 'not ok %d - %s\n' "$checks" "$description"
        failures=$((failures + 1))
    fi
}

equals() { [ "$1" = "$2" ]; }
contains() { grep -Fq -- "$2" "$1"; }
rejects_backend() { ! rootfs_backend_supported "$1" "$2"; }
rejects_resolution() { ! rootfs_resolve_backend "$1" "$2" >/dev/null; }

check "Debian accepts mmdebstrap" rootfs_backend_supported debian mmdebstrap
check "Ubuntu accepts qemu-debootstrap" rootfs_backend_supported ubuntu qemu-debootstrap
check "Arch rejects debootstrap" rejects_backend arch debootstrap
check "explicit incompatible backend is rejected" rejects_resolution alpine multistrap
check "explicit compatible backend is retained" equals "$(rootfs_resolve_backend kali cdebootstrap)" cdebootstrap

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rootfs_backend_config_defaults ubuntu mmdebstrap
ROOTFS_BACKEND_INCLUDE="ca-certificates curl"
ROOTFS_BACKEND_EXCLUDE="documentation"
ROOTFS_MMDEBSTRAP_MODE=unshare
rootfs_backend_config_write "$tmpdir"
rootfs_backend_config_defaults debian debootstrap
rootfs_backend_config_load "$tmpdir" ubuntu mmdebstrap
check "saved package includes round-trip" equals "$ROOTFS_BACKEND_INCLUDE" "ca-certificates curl"
check "saved package excludes round-trip" equals "$ROOTFS_BACKEND_EXCLUDE" documentation
check "saved mmdebstrap mode round-trips" equals "$ROOTFS_MMDEBSTRAP_MODE" unshare

ROOTFS_MULTISTRAP_CLEANUP=yes
ROOTFS_MULTISTRAP_MARKAUTO=yes
ROOTFS_MULTISTRAP_IMPORTANT=no
export ROOTFS_MULTISTRAP_CLEANUP ROOTFS_MULTISTRAP_MARKAUTO ROOTFS_MULTISTRAP_IMPORTANT
multistrap_conf="$tmpdir/multistrap.conf"
rootfs_multistrap_config_write "$multistrap_conf" arm64 /opt/rootfs/test \
    https://deb.debian.org/debian trixie "main,contrib,non-free-firmware" \
    "ca-certificates curl" debian-archive-keyring
check "multistrap config includes selected components" contains "$multistrap_conf" \
    "source=https://deb.debian.org/debian main contrib non-free-firmware"
check "multistrap config includes selected architecture" contains "$multistrap_conf" "arch=arm64"
check "multistrap config includes selected packages" contains "$multistrap_conf" "packages=ca-certificates curl"

printf '1..%d\n' "$checks"
[ "$failures" -eq 0 ]
