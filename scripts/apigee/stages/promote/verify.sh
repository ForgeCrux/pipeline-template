#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_verify() {
  local url="https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/environments/${APIGEE_ENV}/${RESOURCE_TYPE}/${DEPLOY_PROXY}/revisions/${REVISION}/deployments"

  echo "Waiting for Apigee deployment to become ready..."

  local attempt
  for attempt in $(seq 1 20); do
    local response
    response="$(curl --silent --show-error --location \
      --header "Authorization: Bearer $TOKEN" \
      "$url")"

    echo ""
    echo "Attempt: $attempt"

    local state
    state="$(echo "$response" | jq -r '.state // empty')"
    echo "Deployment state: ${state:-UNKNOWN}"

    if [[ "$state" == "READY" ]]; then
      echo ""
      echo "Deployment is READY"
      return 0
    fi

    if [[ "$state" == "ERROR" ]]; then
      echo "ERROR: Deployment entered ERROR state" >&2
      echo "$response"
      return 1
    fi

    sleep 10
  done

  echo "ERROR: Deployment did not reach READY state" >&2
  return 1
}

run_step VERIFY VERIFY_DEPLOYMENT _verify