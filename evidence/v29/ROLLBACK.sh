#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT}"
BASELINE="$ROOT/evidence/v29/rollback-baseline"
case "$TARGET_ROOT" in
  "$ROOT"|"$ROOT/evidence/v29/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
rm -rf "$TARGET_ROOT/NeighborhoodLife"
mkdir -p "$TARGET_ROOT/NeighborhoodLife"
cp -a "$BASELINE/NeighborhoodLife/." "$TARGET_ROOT/NeighborhoodLife/"
for relative in SCOPE.md README.md tests/HandsFreeQA.java tools/launch-multiplayer-qa.ps1; do
  mkdir -p "$TARGET_ROOT/$(dirname "$relative")"
  cp "$BASELINE/$relative" "$TARGET_ROOT/$relative"
done
echo "ROLLBACK RESTORED: production, scope, README, QA agent and launcher from $BASELINE"
