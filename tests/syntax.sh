#!/bin/sh
set -e
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
find "$ROOT" -type f \( -name '*.sh' -o -name 'ish-aok-config' \) -print | while read f; do sh -n "$f"; done
echo 'syntax: ok'
