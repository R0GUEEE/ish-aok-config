#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
find "$BASE/lib" "$BASE/modules" "$BASE/tests" -name '*.sh' -type f | while IFS= read -r f; do sh -n "$f"; done
