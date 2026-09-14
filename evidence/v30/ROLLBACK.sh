#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT}"
BASELINE="$ROOT/evidence/v30/rollback-baseline"
case "$TARGET_ROOT" in
  "$ROOT"|"$ROOT/evidence/v30/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
rm -rf "$TARGET_ROOT/NeighborhoodLife"
mkdir -p "$TARGET_ROOT/NeighborhoodLife" "$TARGET_ROOT/tests"
cp -a "$BASELINE/NeighborhoodLife/." "$TARGET_ROOT/NeighborhoodLife/"
cp "$BASELINE/tests/npc-authority.lua" "$TARGET_ROOT/tests/npc-authority.lua"
echo "ROLLBACK RESTORED: NPC authority and contract test from $BASELINE"
