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

  # Extract token that get_service_token.py just wrote to $GITHUB_OUTPUT.
  local token
  token="$(grep '^access_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  [ -n "$token" ] || { echo "ERROR: service token empty" >&2; return 1; }
  export SERVICE_ACCESS_TOKEN="$token"

  export ENVIRONMENT="$APIGEE_ENV"
  export DEPLOY_PROXY RESOURCE_TYPE

  run_step FORGESPHERE_CONFIGURATION LOAD_CICD_CONFIG _load_cicd_config
}

stage_run FORGESPHERE_CONFIGURATION "ForgeSphere Configuration" _forgesphere_body