#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# GitHub exposes the job result as `job.status` (success, failure, cancelled).
# Default to success if unset so the API never receives an unknown enum value.
RAW_STATUS="${JOB_STATUS:-success}"

case "$(echo "$RAW_STATUS" | tr '[:upper:]' '[:lower:]')" in
  success)            NORMALIZED="COMPLETED" ;;
  failure|cancelled| \
  canceled|timed_out) NORMALIZED="FAILED" ;;
  running)            NORMALIZED="RUNNING" ;;
  *)                  NORMALIZED="COMPLETED" ;;
esac

# Stream a plain log line via pipeline_logs.py stdin (NOT via log_line,
# which may not exist in older _common.sh revisions).
printf '%s\n' "GitHub Actions execution completed with status: $RAW_STATUS ($NORMALIZED)" \
  | python3 "$_LOGS_PY" stdin EXECUTION -- FINAL_STATUS >/dev/null 2>&1 || true

# Emit the terminal event (emit_event exists in every _common.sh version).
emit_event EXECUTION FINAL_STATUS "$NORMALIZED" \
  "GitHub Actions execution completed with status: $RAW_STATUS"

exit 0