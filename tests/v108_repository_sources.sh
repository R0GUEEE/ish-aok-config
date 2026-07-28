#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
grep -Eq "VERSION='(10|11)\.[0-9]+\.[0-9]+'" "$BASE/lib/core.sh"
f="$BASE/modules/zzzzzzzzzzzzz_v108_repository_sources.sh"
[ -s "$f" ]
grep -q 'v108_repository_sources_menu' "$f"
grep -q 'v108_apt_sources_menu' "$f"
grep -q 'https://flathub.org/repo/flathub.flatpakrepo' "$f"
grep -q 'https://registry.npmjs.org/' "$f"
grep -q 'https://pypi.org/simple' "$f"
grep -q 'v104_main_scope_call v108_system_packages_menu' "$f"
sh -n "$f"
echo 'v10.8 repository sources: PASS'
