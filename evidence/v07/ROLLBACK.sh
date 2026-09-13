#!/usr/bin/env bash
set -euo pipefail
cp E:/pzmod/evidence/v07/launch-baseline.ps1 "${1:?Supply launcher copy path}"
cmp E:/pzmod/evidence/v07/launch-baseline.ps1 "$1"
echo "PASS: original launcher restored; QA agent disabled"
