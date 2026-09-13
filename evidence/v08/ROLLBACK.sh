#!/usr/bin/env bash
set -euo pipefail
cp E:/pzmod/evidence/v08/baseline.lua "${1:?Supply QA Lua copy path}"
cmp E:/pzmod/evidence/v08/baseline.lua "$1"
echo "PASS: original QA probe restored"
