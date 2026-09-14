#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT/evidence/v35/rollback-target}"
case "$TARGET_ROOT" in
  "$ROOT/evidence/v35/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
BASELINE="$ROOT/evidence/v35/rollback-baseline"
mkdir -p "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL" \
         "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NL" \
         "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL" \
         "$TARGET_ROOT/tests" "$TARGET_ROOT/tools" \
         "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client" \
         "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server"
cp "$BASELINE/Households.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL/Households.lua"
cp "$BASELINE/HouseholdAuthority.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NL/HouseholdAuthority.lua"
cp "$BASELINE/HouseholdClient.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/HouseholdClient.lua"
cp "$BASELINE/HouseholdPanel.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/HouseholdPanel.lua"
cp "$BASELINE/Domain.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL/Domain.lua"
cp "$BASELINE/NeighborhoodLifeServer.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NeighborhoodLifeServer.lua"
cp "$BASELINE/NeighborhoodNeeds.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NeighborhoodNeeds.lua"
cp "$BASELINE/mod.info" "$TARGET_ROOT/NeighborhoodLife/42/mod.info"
cp "$BASELINE/README.md" "$TARGET_ROOT/README.md"
cp "$BASELINE/SCOPE.md" "$TARGET_ROOT/SCOPE.md"
cp "$BASELINE/pipeline.py" "$TARGET_ROOT/tools/pipeline.py"
cp "$BASELINE/NLQAMultiplayer.lua" "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client/NLQAMultiplayer.lua"
cp "$BASELINE/NLQAMultiplayerServer.lua" "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server/NLQAMultiplayerServer.lua"
echo "ROLLBACK RESTORED: v1.15 household source, tooling and docs; removed v1.16 storage changes from $TARGET_ROOT"
