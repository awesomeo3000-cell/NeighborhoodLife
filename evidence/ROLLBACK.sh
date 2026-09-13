#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
TARGET="${1:?Supply a copy of NeighborhoodNeeds.lua to restore}"
[ -f "$TARGET" ] || exit 2
cp -- "$HERE/NeighborhoodNeeds.baseline.lua" "$TARGET"
printf '%s\n' 'PASS: restored disabled baseline'
