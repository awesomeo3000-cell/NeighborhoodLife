#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT/evidence/v31/rollback-target}"
case "$TARGET_ROOT" in
  "$ROOT/evidence/v31/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
BASELINE="$ROOT/evidence/v31/rollback-baseline"
mkdir -p "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL"
cp "$BASELINE/42/media/lua/client/NL/Plumbob.lua" \
   "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/Plumbob.lua"
cp "$BASELINE/tests-plumbob.lua" "$TARGET_ROOT/tests-plumbob.lua"
echo "ROLLBACK RESTORED: compact plumbob source and contract test from $BASELINE"
