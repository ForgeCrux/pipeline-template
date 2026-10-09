#!/usr/bin/env bash
# _common.sh — shared helpers for Kong Konnect stage scripts.
set -euo pipefail

# scripts/
#   pipeline_logs.py
#   get_service_token.py
#   load_kong_config.py
#   kong/
#     resolve_flow_change_id.sh
#     stages/
#       _common.sh          <-- this file

_STAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # scripts/kong/stages
_KONG_DIR="$(cd "${_STAGES_DIR}/.." && pwd)"                  # scripts/kong
_SCRIPTS_DIR="$(cd "${_KONG_DIR}/.." && pwd)"                 # scripts

_LOGS_PY="${_SCRIPTS_DIR}/pipeline_logs.py"

export _STAGES_DIR _KONG_DIR _SCRIPTS_DIR _LOGS_PY

# ------------------------------------------------------------------
# log_line <stage> <step> <message...>
# ------------------------------------------------------------------
log_line() {
  local stage="$1"; shift
  local step="$1"; shift
  printf '%s\n' "$*" \
    | python3 "$_LOGS_PY" stdin "$stage" -- "$step" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------
# emit_event <stage> <step> <status> <message>
# ------------------------------------------------------------------
emit_event() {
  python3 "$_LOGS_PY" event "$1" -- "$2" --status "$3" --message "$4" || true
}

# ------------------------------------------------------------------
# run_step <stage> <step> <command...>
# ------------------------------------------------------------------
run_step() {
  local stage="$1"; shift
  local step="$1"; shift

  set +e
  "$@" 2>&1 | python3 "$_LOGS_PY" stdin "$stage" -- "$step"
  local result=${PIPESTATUS[0]}
  set -e

  local status="FAILED"
  [ "$result" -eq 0 ] && status="COMPLETED"

  python3 "$_LOGS_PY" event "$stage" -- "$step" \
    --status "$status" \
    --message "$step finished with exit code $result" || true

  return "$result"
}

# ------------------------------------------------------------------
# stage_run <stage> <title> <body-function>
# ------------------------------------------------------------------
stage_run() {
  local stage="$1"
  local title="$2"
  shift 2

  echo "::group::${title}"
  emit_event "$stage" STAGE_STARTED RUNNING "${title} stage started"
  log_line   "$stage" STAGE_STARTED "${title} stage started"

  local result=0
  "$@" || result=$?

  local status="COMPLETED"
  [ "$result" -ne 0 ] && status="FAILED"

  log_line   "$stage" STAGE_COMPLETED "${title} stage completed (status=$status exit=$result)"
  emit_event "$stage" STAGE_COMPLETED "$status" "${title} stage completed"
  echo "::endgroup::"

  return "$result"
}