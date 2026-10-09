#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_get_token() {
  local response; response="$(mktemp)"
  trap 'rm -f "$response"' EXIT

  local status
  status="$(curl --silent --show-error --location \
    --output "$response" \
    --write-out "%{http_code}" \
    "$TOKEN_SERVICE_URL")"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "ERROR: Failed to obtain Apigee access token (HTTP $status)"
    cat "$response"
    return 1
  fi

  local token
  token="$(jq -r '.access_token // empty' "$response")"
  [ -n "$token" ] || { echo "access_token missing from token service response" >&2; return 1; }

  echo "::add-mask::$token"
  echo "access_token=$token" >> "$GITHUB_OUTPUT"
  echo "Apigee access token obtained successfully"
}

run_step APIGEE_AUTH GET_ACCESS_TOKEN _get_token