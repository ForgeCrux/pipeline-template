#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

RAW="${JOB_STATUS:-success}"
case "$(echo "$RAW" | tr '[:upper:]' '[:lower:]')" in
  success)             N="COMPLETED" ;;
  failure|cancelled)   N="FAILED" ;;
  *)                   N="COMPLETED" ;;
esac

log_line  EXECUTION FINAL_STATUS "GitHub Actions execution completed with status: $RAW ($N)"
emit_event EXECUTION FINAL_STATUS "$N" "GitHub Actions execution completed with status: $RAW"
exit 0