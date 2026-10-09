#!/usr/bin/env bash
# _common.sh — shared helpers for Apigee stage scripts.

set -euo pipefail

# Directory layout:
#   scripts/
#     pipeline_logs.py
#     get_service_token.py
#     load_cicd_configs.py
#     apigee/
#       resolve_flow_change_id.sh
#       stages/
#         _common.sh          <-- this file
#         <stage>.sh

_STAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # scripts/apigee/stages
_APIGEE_DIR="$(cd "${_STAGES_DIR}/.." && pwd)"                # scripts/apigee
_SCRIPTS_DIR="$(cd "${_APIGEE_DIR}/.." && pwd)"               # scripts

_LOGS_PY="${_SCRIPTS_DIR}/pipeline_logs.py"

# Expose these to sourcing scripts so they don't have to recompute.
export _STAGES_DIR _APIGEE_DIR _SCRIPTS_DIR _LOGS_PY

# run_step <stage> <step> <command...>
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

# emit_event <stage> <step> <status> <message>
emit_event() {
  python3 "$_LOGS_PY" event "$1" -- "$2" --status "$3" --message "$4" || true
}

# stage_run <stage> <title> <body-function>
stage_run() {
  local stage="$1"
  local title="$2"
  shift 2

  echo "::group::${title}"
  emit_event "$stage" STAGE_STARTED RUNNING "${title} stage started"

  local result=0
  "$@" || result=$?

  local status="COMPLETED"
  [ "$result" -ne 0 ] && status="FAILED"

  emit_event "$stage" STAGE_COMPLETED "$status" "${title} stage completed"
  echo "::endgroup::"

  return "$result"
}

# append_output <key> <value> — writes to $GITHUB_OUTPUT (no-op if unset).
append_output() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}