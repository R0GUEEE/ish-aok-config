#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
grep -q 'v109_install_missing_keyrings' "$BASE/modules/zzzzzzzzzzzzzz_v109_keyring_manager.sh"
grep -q 'Install missing keyring packages' "$BASE/modules/zzzzzzzzzzzzzz_v109_keyring_manager.sh"
grep -q 'signed-by=' "$BASE/modules/zzzzzzzzzzzzzz_v109_keyring_manager.sh"
grep -q 'pacman-key --populate' "$BASE/modules/zzzzzzzzzzzzzz_v109_keyring_manager.sh"
sh -n "$BASE/modules/zzzzzzzzzzzzzz_v109_keyring_manager.sh"
printf 'v10.9 keyring manager test passed\n'
