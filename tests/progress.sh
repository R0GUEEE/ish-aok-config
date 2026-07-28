#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HOME=${HOME:-/tmp}
. "$BASE/lib/core.sh"
. "$BASE/lib/ui.sh"
. "$BASE/lib/progress.sh"
UI=text
PROGRESS_ENABLED=no
DRY_RUN=no
progress_run 'Progress smoke test' sh -c 'printf "step one\n"; printf "step two\n"'
[ "$?" -eq 0 ]
grep -q 'step two' "$PROGRESS_LAST_LOG"
progress_run 'Expected failure' sh -c 'printf "failed\n"; exit 7' && exit 1 || rc=$?
[ "$rc" -eq 7 ]
