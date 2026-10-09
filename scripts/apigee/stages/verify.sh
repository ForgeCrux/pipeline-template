#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_verify_deployment() {
  [ -n "${TOKEN:-}" ] || { echo "ERROR: TOKEN empty" >&2; return 1; }

  local status
  status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/${RESOURCE_TYPE}/${DEPLOY_PROXY}")"

  [ "$status" = "200" ] || { echo "Verification failed: HTTP $status" >&2; return 1; }
  echo "Proxy verified successfully"
}

_verify_body() {
  run_step VERIFY VERIFY_DEPLOYMENT _verify_deployment
}

stage_run VERIFY "Verify" _verify_body