#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_load_config() {
  local response="cicd-config-response.json"

  curl --fail-with-body --silent --show-error --location \
    --request GET \
    "${CICD_CONFIG_URL%/}/${CICD_CONFIG_ID}/all?filtered=true" \
    --header "Authorization: Bearer ${SERVICE_ACCESS_TOKEN}" \
    --header "Accept: application/json" \
    --output "$response"

  test -s "$response"

  python3 "${_SCRIPTS_DIR}/load_kong_config.py" "$response"
}

run_step KONG_SETUP LOAD_CICD_CONFIG _load_config