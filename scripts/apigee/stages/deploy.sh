#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_deploy_proxy() {
  local base="https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/${RESOURCE_TYPE}/${DEPLOY_PROXY}/revisions/${REVISION}/deployments"

  [ -f "$SERVICE_ACCOUNT_FILE" ] || { echo "ERROR: SA file missing: $SERVICE_ACCOUNT_FILE" >&2; return 1; }

  local email
  email="$(jq -r '.client_email // empty' "$SERVICE_ACCOUNT_FILE")"
  [ -n "$email" ] || { echo "ERROR: client_email missing" >&2; return 1; }

  local encoded
  encoded="$(printf '%s' "$email" | jq -sRr @uri)"

  local response
  response="$(curl --silent --show-error --write-out '\nHTTP_STATUS:%{http_code}\n' \
    -X POST -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{ "override": true }' \
    "${base}?serviceAccount=${encoded}")"

  local status
  status="$(echo "$response" | grep HTTP_STATUS | cut -d':' -f2)"

  if [ "$status" -ne 200 ]; then
    echo "Deployment failed:"; echo "$response"; return 1
  fi
  echo "Deployment successful"
}

_deploy_body() {
  run_step DEPLOYMENT DEPLOY_PROXY _deploy_proxy
}

stage_run DEPLOYMENT "Deployment" _deploy_body