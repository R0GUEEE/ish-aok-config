#!/bin/sh
set -eu
PREFIX=${PREFIX:-/usr/local}
rm -f "${DESTDIR:-}$PREFIX/bin/ish-aok-config"
rm -rf "${DESTDIR:-}$PREFIX/lib/ish-aok-config"
echo 'iSH-AOK Config removed. User backups and state were retained.'
