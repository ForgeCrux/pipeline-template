#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

RAW_STATUS="${JOB_STATUS:-success}"
case "$(echo "$RAW_STATUS" | tr '[:upper:]' '[:lower:]')" in
  success)              NORMALIZED="COMPLETED" ;;
  failure|cancelled| \
  canceled|timed_out)   NORMALIZED="FAILED" ;;
  running)              NORMALIZED="RUNNING" ;;
  *)                    NORMALIZED="COMPLETED" ;;
esac

log_line EXECUTION FINAL_STATUS \
  "GitHub Actions execution completed with status: $RAW_STATUS ($NORMALIZED)"

emit_event EXECUTION FINAL_STATUS "$NORMALIZED" \
  "GitHub Actions execution completed with status: $RAW_STATUS"

exit 0