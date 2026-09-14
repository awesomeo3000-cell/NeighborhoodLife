#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT/evidence/v34/rollback-target}"
case "$TARGET_ROOT" in
  "$ROOT/evidence/v34/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
BASELINE="$ROOT/evidence/v34/rollback-baseline"
mkdir -p "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL" \
         "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NL" \
         "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL" \
         "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client" \
         "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server" \
         "$TARGET_ROOT/tests" "$TARGET_ROOT/tools"
cp "$BASELINE/Domain.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL/Domain.lua"
cp "$BASELINE/NeighborhoodLifeServer.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NeighborhoodLifeServer.lua"
cp "$BASELINE/NeighborhoodNeeds.lua" "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NeighborhoodNeeds.lua"
cp "$BASELINE/mod.info" "$TARGET_ROOT/NeighborhoodLife/42/mod.info"
cp "$BASELINE/hud.lua" "$TARGET_ROOT/tests/hud.lua"
cp "$BASELINE/pipeline.py" "$TARGET_ROOT/tools/pipeline.py"
cp "$BASELINE/README.md" "$TARGET_ROOT/README.md"
cp "$BASELINE/SCOPE.md" "$TARGET_ROOT/SCOPE.md"
cp "$BASELINE/NLQAMultiplayer.lua" "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/client/NLQAMultiplayer.lua"
cp "$BASELINE/NLQAMultiplayerServer.lua" "$TARGET_ROOT/qa/NeighborhoodQA/42/media/lua/server/NLQAMultiplayerServer.lua"
for path in \
  "$TARGET_ROOT/NeighborhoodLife/42/media/lua/shared/NL/Households.lua" \
  "$TARGET_ROOT/NeighborhoodLife/42/media/lua/server/NL/HouseholdAuthority.lua" \
  "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/HouseholdClient.lua" \
  "$TARGET_ROOT/NeighborhoodLife/42/media/lua/client/NL/HouseholdPanel.lua" \
  "$TARGET_ROOT/tests/households.lua" \
  "$TARGET_ROOT/tests/household-authority.lua" \
  "$TARGET_ROOT/tests/household-panel.lua"; do
  rm -f "$path"
done
echo "ROLLBACK RESTORED: v1.14 source, tooling, QA scripts and docs; removed v1.15 household files from $TARGET_ROOT"
