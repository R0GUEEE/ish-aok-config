#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
"$ROOT/ish-aok-config" --v11-capability-report ubuntu | grep -q '^rootfs_builder.*yes'
"$ROOT/ish-aok-config" --software-catalog-report | grep -q '^starship'
"$ROOT/ish-aok-config" --v11-plugin-report | grep -q '^example|Example v11 Module|1.0.0|no|'
printf 'v11 CLI reports: PASS\n'
