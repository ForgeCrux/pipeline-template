#!/usr/bin/env bash
# _common.sh — shared helpers for stage scripts.

set -euo pipefail

_STAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SCRIPTS_DIR="$(cd "${_STAGES_DIR}/.." && pwd)"
_LOGS_PY="${_SCRIPTS_DIR}/pipeline_logs.py"

# run_step <stage> <step> <command...>
# Pipes command stdout/stderr through pipeline_logs.py stdin and emits
# a COMPLETED/FAILED event for the step. Returns the command's exit code.
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
# Wraps a stage: opens ::group::, emits STAGE_STARTED, runs the body,
# then emits STAGE_COMPLETED (or FAILED) and closes the group.
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

# append_output <key> <value>  — writes to $GITHUB_OUTPUT (no-op if unset).
append_output() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}