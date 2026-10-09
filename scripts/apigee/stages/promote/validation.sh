#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_validate() {
  if [[ "$OPERATION" != "promote" && "$OPERATION" != "rollback" ]]; then
    echo "ERROR: operation must be promote or rollback (got: $OPERATION)" >&2
    return 1
  fi

  if [[ "$RESOURCE_TYPE" != "apis" && "$RESOURCE_TYPE" != "sharedflows" ]]; then
    echo "ERROR: resourcetype must be apis or sharedflows (got: $RESOURCE_TYPE)" >&2
    return 1
  fi

  local var
  for var in NEXUS_VERSION DEPLOY_PROXY APIGEE_ORG APIGEE_ENV CICD_CONFIG_URL CICD_CONFIG_ID; do
    if [ -z "${!var:-}" ]; then
      echo "ERROR: $var must not be empty" >&2
      return 1
    fi
  done

  echo "=========================================="
  echo "APIGEE RELEASE REQUEST"
  echo "=========================================="
  echo "Operation      : $OPERATION"
  echo "Organization   : $APIGEE_ORG"
  echo "Environment    : $APIGEE_ENV"
  echo "Resource       : $RESOURCE_TYPE"
  echo "Name           : $DEPLOY_PROXY"
  echo "Nexus Version  : $NEXUS_VERSION"
  echo "ForgeSphere ID : $CICD_CONFIG_ID"
  echo "=========================================="
}

run_step VALIDATION VALIDATE_INPUTS _validate