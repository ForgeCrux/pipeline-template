#!/usr/bin/env bash
# _common.sh — shared helpers for Apigee stage scripts.

set -euo pipefail

_STAGES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_APIGEE_DIR="$(cd "${_STAGES_DIR}/.." && pwd)"
_SCRIPTS_DIR="$(cd "${_APIGEE_DIR}/.." && pwd)"

_LOGS_PY="${_SCRIPTS_DIR}/pipeline_logs.py"

export _STAGES_DIR _APIGEE_DIR _SCRIPTS_DIR _LOGS_PY

# ----- Normalize credential env vars (issue: TOKEN unbound) ------
set +u
if [ -z "${TOKEN:-}" ] && [ -n "${ACCESS_TOKEN:-}" ]; then
  export TOKEN="$ACCESS_TOKEN"
fi
if [ -z "${ACCESS_TOKEN:-}" ] && [ -n "${TOKEN:-}" ]; then
  export ACCESS_TOKEN="$TOKEN"
fi
set -u

# Tracks whether we are inside a stage_run body. Read by run_step/run_step_soft.
_IN_STAGE="${_IN_STAGE:-0}"

# Accumulates soft-failure messages for the enclosing stage_run.
_WARNINGS=()

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
#
# Streams stdout/stderr. On success inside a stage, no status event
# is emitted — stage_run will publish the final STAGE_COMPLETED.
# On success outside a stage, COMPLETED is emitted immediately.
# On failure, FAILED is always emitted so it surfaces immediately,
# and stage_run will additionally report the final FAILED.
# ------------------------------------------------------------------
run_step() {
  local stage="$1"; shift
  local step="$1"; shift

  set +e
  "$@" 2>&1 | python3 "$_LOGS_PY" stdin "$stage" -- "$step"
  local result=${PIPESTATUS[0]}
  set -e

  if [ "$result" -eq 0 ]; then
    # Inside a stage, defer the final COMPLETED to stage_run.
    if [ "$_IN_STAGE" != "1" ]; then
      python3 "$_LOGS_PY" event "$stage" -- "$step" \
        --status "COMPLETED" \
        --message "$step finished with exit code 0" || true
    fi
  else
    python3 "$_LOGS_PY" event "$stage" -- "$step" \
      --status "FAILED" \
      --message "$step finished with exit code $result" || true
  fi

  return "$result"
}

# ------------------------------------------------------------------
# run_step_soft <stage> <step> <command...>
#
# Streams output. On failure, records a WARNING instead of FAILED and
# returns 0. The containing stage_run will publish
# "STAGE_COMPLETED ... WARNING: ..." at the end.
# Outside a stage_run, COMPLETED is emitted immediately with the warning.
# ------------------------------------------------------------------
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
        --status "COMPLETED" \
        --message "$step finished with exit code 0" || true
    fi
    return 0
  fi

  local msg="WARNING: $step failed with exit code $result (ignored)"
  _WARNINGS+=("$msg")

  if [ "$_IN_STAGE" != "1" ]; then
    python3 "$_LOGS_PY" event "$stage" -- "$step" \
      --status "COMPLETED" \
      --message "$msg" || true
  else
    log_line "$stage" "$step" "$msg"
  fi

  return 0
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

  local prev_in_stage="$_IN_STAGE"
  local prev_warnings_len="${#_WARNINGS[@]}"

  _IN_STAGE=1

  local result=0
  "$@" || result=$?

  _IN_STAGE="$prev_in_stage"

  # Warnings produced during this stage body (slice from saved length).
  local stage_warnings=("${_WARNINGS[@]:$prev_warnings_len}")

  local status="COMPLETED"
  local message="${title} stage completed"

  if [ "$result" -ne 0 ]; then
    status="FAILED"
    message="${title} stage failed (exit=$result)"
  elif [ "${#stage_warnings[@]}" -gt 0 ]; then
    message="WARNING: ${title} stage completed with warnings: $(IFS='; '; echo "${stage_warnings[*]}")"
  fi

  log_line   "$stage" STAGE_COMPLETED "$message"
  emit_event "$stage" STAGE_COMPLETED "$status" "$message"
  echo "::endgroup::"

  return "$result"
}

# ------------------------------------------------------------------
# append_output <key> <value>
# ------------------------------------------------------------------
append_output() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
}