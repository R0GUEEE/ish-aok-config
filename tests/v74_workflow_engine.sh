#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
HOME_DIR="${TMPDIR:-/tmp}/ish-aok-v74-test.$$"
out=$(HOME="$HOME_DIR" "$BASE/ish-aok-config" --workflow-report)
printf '%s\n' "$out" | grep -q 'Workflow Engine'
printf '%s\n' "$out" | grep -q 'health_audit'
grep -Eq "VERSION='(10\.[0-9]+\.[0-9]+|[1-9][1-9][0-9]*\.[0-9]+\.[0-9]+)'|VERSION='([7-9]\.)" "$BASE/lib/core.sh"
grep -q 'workflow_run_file' "$BASE/lib/workflow_v74.sh"
grep -q 'workflow_engine_menu' "$BASE/modules/workflow_v74.sh"
grep -q "command_register workflows" "$BASE/lib/dispatcher_v73.sh"
mkdir -p "$HOME_DIR/.local/state/ish-aok-config/workflows/pipelines"
printf 'meta\tname\tTest Workflow\nmeta\tdescription\tWorkflow engine smoke test\nstep\tone\tRecord test\tactivity_add\tworkflow_test completed\t\t\t\t\n' > "$HOME_DIR/.local/state/ish-aok-config/workflows/pipelines/test.workflow"
HOME="$HOME_DIR" "$BASE/ish-aok-config" --workflow test >/dev/null
find "$HOME_DIR/.local/state/ish-aok-config/workflows/runs" -name status.tsv -type f | grep -q .
grep -R -q 'success' "$HOME_DIR/.local/state/ish-aok-config/workflows/runs"/*/status.tsv
rm -rf "$HOME_DIR"
printf '%s\n' 'v7.4 workflow engine test passed'
