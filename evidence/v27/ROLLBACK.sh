#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_ROOT="${TARGET_ROOT:-$ROOT}"
BASELINE="$ROOT/evidence/v27/baseline"
case "$TARGET_ROOT" in
  "$ROOT"|"$ROOT/evidence/v27/rollback-target") ;;
  *) echo "ROLLBACK TARGET OUTSIDE WORKSPACE: $TARGET_ROOT" >&2; exit 2 ;;
esac
rm -rf "$TARGET_ROOT/NeighborhoodLife"
mkdir -p "$TARGET_ROOT/NeighborhoodLife"
cp -a "$BASELINE/." "$TARGET_ROOT/NeighborhoodLife/"
echo "ROLLBACK RESTORED: $TARGET_ROOT/NeighborhoodLife from $BASELINE"