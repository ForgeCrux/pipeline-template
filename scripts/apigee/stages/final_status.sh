#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

FINAL_STATUS="${JOB_STATUS:-unknown}"
emit_event EXECUTION FINAL_STATUS "$FINAL_STATUS" \
  "GitHub Actions execution completed with status: $FINAL_STATUS"
exit 0