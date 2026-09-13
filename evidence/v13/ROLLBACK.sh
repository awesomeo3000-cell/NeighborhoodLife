#!/usr/bin/env bash
set -euo pipefail
cp E:/pzmod/evidence/v13/baseline.lua "${1:?Supply QA Lua copy path}"
cmp E:/pzmod/evidence/v13/baseline.lua "$1"
echo "PASS: original stationary QA probe restored"
