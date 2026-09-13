#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
TARGET="${1:?Supply the settings file to restore}"
[ -f "$TARGET" ] || exit 2
cp -- "$HERE/default.original.txt" "$TARGET"
echo 'PASS: original mod list restored'
