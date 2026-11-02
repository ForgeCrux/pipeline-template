#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}

_load_config() {
  local token
  token="$(grep '^access_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  [ -n "$token" ] || { echo "ERROR: get_service_token.py produced no access_token" >&2; return 1; }
  export SERVICE_ACCESS_TOKEN="$token"
  python3 "${_SCRIPTS_DIR}/load_microservice_config.py"
}

_forgesphere_body() {
  run_step FORGESPHERE_CONFIGURATION GET_SERVICE_TOKEN _get_token
  run_step FORGESPHERE_CONFIGURATION LOAD_CICD_CONFIG _load_config
}

stage_run FORGESPHERE_CONFIGURATION "ForgeSphere Configuration" _forgesphere_body