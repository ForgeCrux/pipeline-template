#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# GitHub exposes the job result as `job.status` (values: success,
# failure, cancelled). The workflow maps that in. If it isn't set
# (e.g. invoked outside a workflow job), default to COMPLETED so
# the API never receives an unknown enum value.
RAW_STATUS="${JOB_STATUS:-success}"

# Normalize GitHub-style values to the service's expected enum.
# pipeline_logs.py's JOB_STATUS_MAP does this too, but doing it here
# guarantees a valid value even if the map drifts.
case "$(echo "$RAW_STATUS" | tr '[:upper:]' '[:lower:]')" in
  success)             NORMALIZED="COMPLETED" ;;
  failure|cancelled| \
  canceled|timed_out)  NORMALIZED="FAILED" ;;
  running)             NORMALIZED="RUNNING" ;;
  *)                   NORMALIZED="COMPLETED" ;;
esac

log_line  EXECUTION FINAL_STATUS \
  "GitHub Actions execution completed with status: $RAW_STATUS ($NORMALIZED)"

emit_event EXECUTION FINAL_STATUS "$NORMALIZED" \
  "GitHub Actions execution completed with status: $RAW_STATUS"

exit 0