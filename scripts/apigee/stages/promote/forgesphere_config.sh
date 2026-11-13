#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_get_service_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}

_load_config() {
  local token
  token="$(grep '^access_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  [ -n "$token" ] || { echo "ERROR: service token empty" >&2; return 1; }
  export SERVICE_ACCESS_TOKEN="$token"
  
  # Use v2 API loader
  python3 "${_SCRIPTS_DIR}/load_cicd_config.py"
}

_body() {
  run_step KONG_CONFIG GET_SERVICE_TOKEN _get_service_token
  run_step KONG_CONFIG LOAD_CICD_CONFIG _load_config
}
stage_run KONG_CONFIG "ForgeSphere Configuration" _body
