#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

RAW_STATUS="${JOB_STATUS:-success}"

case "$(echo "$RAW_STATUS" | tr '[:upper:]' '[:lower:]')" in
  success)             NORMALIZED="COMPLETED" ;;
  failure|cancelled)   NORMALIZED="FAILED" ;;
  *)                   NORMALIZED="COMPLETED" ;;
esac

# Report the result to the migration service if needed
if [ -n "${RESULT_CALLBACK_URL:-}" ] && [ "${VALIDATE_ONLY:-false}" = "false" ]; then
  run_step EXECUTION REPORT_RESULT _report_callback
fi
# A validate_only run skips these steps; report them as skipped, or the flow stays "in progress".
if [ "${VALIDATE_ONLY:-false}" = "true" ]; then
  for stage in KONG_DEPLOY KONG_DUMP KONG_NEXUS; do
    emit_event "$stage" STAGE_SKIPPED SKIPPED "Skipped: validate_only run"
  done
fi
log_line EXECUTION FINAL_STATUS "GitHub Actions execution completed with status: $RAW_STATUS ($NORMALIZED)"
emit_event EXECUTION FINAL_STATUS "$NORMALIZED" "GitHub Actions execution completed with status: $RAW_STATUS"

exit 0
