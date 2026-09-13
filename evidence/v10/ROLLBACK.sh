#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: ROLLBACK.sh TARGET_DIRECTORY}"
if [[ "$target" == *:* ]]; then target="$(cygpath -u "$target")"; fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="${target}.rollback-tmp"
rm -rf "$tmp" "$target"
mkdir -p "$tmp" "$target"
git -C "$root" archive HEAD:NeighborhoodLife | tar -x -C "$tmp"
cp -R "$tmp"/. "$target"/
rm -rf "$tmp"
printf 'PASS: restored NeighborhoodLife from baseline commit %s\n' "$(git -C "$root" rev-parse --short HEAD)"
