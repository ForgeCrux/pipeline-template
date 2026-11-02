#!/usr/bin/env bash
# _common.sh — shared helpers for Microservice stage scripts.
set -euo pipefail

_STAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_MS_DIR="$(cd "${_STAGES_DIR}/.." && pwd)"
_SCRIPTS_DIR="$(cd "${_MS_DIR}/.." && pwd)"

_LOGS_PY="${_SCRIPTS_DIR}/pipeline_logs.py"

export _STAGES_DIR _MS_DIR _SCRIPTS_DIR _LOGS_PY

_IN_STAGE="${_IN_STAGE:-0}"
_WARNINGS=()

log_line() {
  local stage="$1"; shift
  local step="$1"; shift
  printf '%s\n' "$*" \
    | python3 "$_LOGS_PY" stdin "$stage" -- "$step" >/dev/null 2>&1 || true
}

emit_event() {
  python3 "$_LOGS_PY" event "$1" -- "$2" --status "$3" --message "$4" || true
}

run_step() {
  local stage="$1"; shift
  local step="$1"; shift
  set +e
  "$@" 2>&1 | python3 "$_LOGS_PY" stdin "$stage" -- "$step"
  local result=${PIPESTATUS[0]}
  set -e

  if [ "$result" -eq 0 ]; then
    if [ "$_IN_STAGE" != "1" ]; then
      python3 "$_LOGS_PY" event "$stage" -- "$step" \
        --status "COMPLETED" --message "$step finished with exit code 0" || true
    fi
  else
    python3 "$_LOGS_PY" event "$stage" -- "$step" \
      --status "FAILED" --message "$step finished with exit code $result" || true
  fi
  return "$result"
}

run_step_soft() {
  local stage="$1"; shift
  local step="$1"; shift
  set +e
  "$@" 2>&1 | python3 "$_LOGS_PY" stdin "$stage" -- "$step"
  local result=${PIPESTATUS[0]}
  set -e

  if [ "$result" -eq 0 ]; then
    if [ "$_IN_STAGE" != "1" ]; then
      python3 "$_LOGS_PY" event "$stage" -- "$step" \
        --status "COMPLETED" --message "$step finished with exit code 0" || true
    fi
    return 0
  fi

  local msg="WARNING: $step failed with exit code $result (ignored)"
  _WARNINGS+=("$msg")
  if [ "$_IN_STAGE" != "1" ]; then
    python3 "$_LOGS_PY" event "$stage" -- "$step" \
      --status "COMPLETED" --message "$msg" || true
  else
    log_line "$stage" "$step" "$msg"
  fi
  return 0
}

stage_run() {
  local stage="$1"
  local title="$2"
  shift 2

  echo "::group::${title}"
  emit_event "$stage" STAGE_STARTED RUNNING "${title} stage started"
  log_line   "$stage" STAGE_STARTED "${title} stage started"

  # Subshell + set -e enforces fail-fast inside the body.
  ( set -e; "$@" )
  local result=$?

  local status="COMPLETED"
  local message="${title} stage completed"
  if [ "$result" -ne 0 ]; then
    status="FAILED"
    message="${title} stage failed (exit=$result)"
  fi

  log_line   "$stage" STAGE_COMPLETED "$message"
  emit_event "$stage" STAGE_COMPLETED "$status" "$message"
  echo "::endgroup::"
  return "$result"
}