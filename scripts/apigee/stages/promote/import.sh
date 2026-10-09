#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_import() {
  local url="https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/${RESOURCE_TYPE}?action=import&name=${DEPLOY_PROXY}"
  local response; response="$(mktemp)"
  trap 'rm -f "$response"' EXIT

  echo "=========================================="
  echo "APIGEE IMPORT"
  echo "=========================================="
  echo "Operation    : $OPERATION"
  echo "Organization : $APIGEE_ORG"
  echo "Resource     : $RESOURCE_TYPE"
  echo "Name         : $DEPLOY_PROXY"
  echo "Version      : $NEXUS_VERSION"
  echo "=========================================="

  local status
  status="$(curl --silent --show-error --location \
    --request POST \
    --header "Authorization: Bearer $TOKEN" \
    --form "file=@${ARTIFACT_FILE}" \
    --output "$response" \
    --write-out "%{http_code}" \
    "$url")"

  echo "Apigee Import HTTP Status: $status"
  echo ""
  echo "========== APIGEE IMPORT RESPONSE =========="
  cat "$response"
  echo ""
  echo "============================================"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "ERROR: Apigee import failed" >&2
    return 1
  fi

  local revision
  revision="$(jq -r '.revision // empty' "$response")"
  [ -n "$revision" ] || { echo "Revision was not returned by Apigee" >&2; return 1; }

  echo "New Apigee revision: $revision"
  echo "revision=$revision" >> "$GITHUB_OUTPUT"
}

run_step IMPORT IMPORT_PACKAGE _import