#!/usr/bin/env bash
set -euo pipefail
ROOT="${TARGET_ROOT:?TARGET_ROOT is required}"
BASE="$(cd "$(dirname "$0")/rollback-baseline" && pwd)"
mkdir -p "$ROOT"
cp -R "$BASE/NeighborhoodLife/42" "$ROOT/"
cp -R "$BASE/qa" "$ROOT/"
cp -R "$BASE/tests" "$ROOT/"
cp -R "$BASE/tools" "$ROOT/"
cp "$BASE/README.md" "$ROOT/README.md"
cp "$BASE/SCOPE.md" "$ROOT/SCOPE.md"
printf '%s\n' 'ROLLBACK RESTORED: baseline production and QA/test trees'