#!/usr/bin/env bash
set -euo pipefail
python E:/pzmod/tools/rollback-v03.py "${1:?Supply explicit mod directory}"
