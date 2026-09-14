#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT/evidence/v32/rollback-target}"
case "$TARGET_ROOT" in
  "$ROOT/evidence/v32/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
BASELINE="$ROOT/evidence/v32/rollback-baseline"
mkdir -p "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL"
cp "$BASELINE/42/media/lua/client/NL/NpcClient.lua" \
   "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/NpcClient.lua"
cp "$BASELINE/tests-npc-client.lua" "$TARGET_ROOT/tests-npc-client.lua"
echo "ROLLBACK RESTORED: NPC client movement source and contract test from $BASELINE"
