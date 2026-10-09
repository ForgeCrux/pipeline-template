#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_deploy() {
  local url="https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/${RESOURCE_TYPE}/${DEPLOY_PROXY}/revisions/${REVISION}/deployments?override=true"
  local response; response="$(mktemp)"
  trap 'rm -f "$response"' EXIT

  echo "=========================================="
  echo "APIGEE DEPLOYMENT"
  echo "=========================================="
  echo "Operation    : $OPERATION"
  echo "Environment  : $APIGEE_ENV"
  echo "Proxy        : $DEPLOY_PROXY"
  echo "Nexus Version: $NEXUS_VERSION"
  echo "Revision     : $REVISION"
  echo "=========================================="

  local status
  status="$(curl --silent --show-error --location \
    --request POST \
    --header "Authorization: Bearer $TOKEN" \
    --output "$response" \
    --write-out "%{http_code}" \
    "$url")"

  echo "Deployment HTTP Status: $status"
  echo ""
  echo "========== DEPLOYMENT RESPONSE =========="
  cat "$response"
  echo ""
  echo "========================================="

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "ERROR: Apigee deployment failed" >&2
    return 1
  fi

  echo "Deployment request successful"
}

run_step DEPLOY DEPLOY_REVISION _deploy