#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT/evidence/v33/rollback-target}"
case "$TARGET_ROOT" in
  "$ROOT/evidence/v33/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
BASELINE="$ROOT/evidence/v33/rollback-baseline"
mkdir -p "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client" \
         "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server"
cp "$BASELINE/README.md" "$TARGET_ROOT/README.md"
cp "$BASELINE/SCOPE.md" "$TARGET_ROOT/SCOPE.md"
cp "$BASELINE/NLQAMultiplayer.lua" \
   "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client/NLQAMultiplayer.lua"
cp "$BASELINE/NLQAMultiplayerServer.lua" \
   "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server/NLQAMultiplayerServer.lua"
echo "ROLLBACK RESTORED: QA inventory probe and scope docs from $BASELINE"
