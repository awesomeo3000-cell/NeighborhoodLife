#!/usr/bin/env bash
set -euo pipefail
python E:/pzmod/tools/rollback-v02.py "${1:?Supply the explicit mod directory to restore}"
