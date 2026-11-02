#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_service_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}

_load_cicd_config() {
  python3 "${_SCRIPTS_DIR}/load_cicd_configs.py"
}

_forgesphere_body() {
  run_step FORGESPHERE_CONFIGURATION GET_SERVICE_TOKEN _get_service_token

  local token
  token="$(grep '^access_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  [ -n "$token" ] || { log_line FORGESPHERE_CONFIGURATION LOAD_CICD_CONFIG \
                        "ERROR: service token empty"; return 1; }
  export SERVICE_ACCESS_TOKEN="$token"

  # ENVIRONMENT = ForgeSphere environment group (DEV/QA/...).
  # APIGEE_ENV  = Apigee deployment target (dev/prod/...).
  # They are conceptually distinct; prefer ENVIRONMENT if set.
  if [ -z "${ENVIRONMENT:-}" ] && [ -n "${APIGEE_ENV:-}" ]; then
    export ENVIRONMENT="$APIGEE_ENV"
  fi

  # RESOURCE_TYPE and APIGEE_ENV are already exported by the caller.

  run_step FORGESPHERE_CONFIGURATION LOAD_CICD_CONFIG _load_cicd_config
}

stage_run FORGESPHERE_CONFIGURATION "ForgeSphere Configuration" _forgesphere_body