#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}

_load_config() {
  local token
  token="$(grep '^access_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  [ -n "$token" ] || { echo "ERROR: service token empty" >&2; return 1; }
  
  export SERVICE_ACCESS_TOKEN="$token"
  python3 "${_SCRIPTS_DIR}/load_kong_config.py"
}

_forgesphere_body() {
  run_step FORGESPHERE_CONFIGURATION GET_SERVICE_TOKEN _get_token
  run_step FORGESPHERE_CONFIGURATION LOAD_CICD_CONFIG _load_config
  
  # Extract Kong config values to GITHUB_OUTPUT for workflow use
  local kong_host
  kong_host="$(grep '^kong_host_url=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  local kong_cp
  kong_cp="$(grep '^kong_control_plane=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  local kong_mode
  kong_mode="$(grep '^kong_deck_mode=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  local kong_pat
  kong_pat="$(grep '^kong_pat_token=' "$GITHUB_OUTPUT" | tail -1 | cut -d'=' -f2-)"
  
  echo "kong_host_url=$kong_host" >> "$GITHUB_OUTPUT"
  echo "kong_control_plane=$kong_cp" >> "$GITHUB_OUTPUT"
  echo "kong_deck_mode=$kong_mode" >> "$GITHUB_OUTPUT"
  echo "kong_pat_token=$kong_pat" >> "$GITHUB_OUTPUT"
}

stage_run KONG_CONFIG "ForgeSphere Configuration" _forgesphere_body