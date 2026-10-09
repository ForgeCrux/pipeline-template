#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_summary() {
  local body
  body="$(
    cat <<EOF
## Apigee ${OPERATION} Successful

| Property | Value |
|---|---|
| Operation | ${OPERATION} |
| Apigee Org | ${APIGEE_ORG} |
| Environment | ${APIGEE_ENV} |
| Resource Type | ${RESOURCE_TYPE} |
| Proxy / Shared Flow | ${DEPLOY_PROXY} |
| Nexus Version | ${NEXUS_VERSION} |
| Apigee Revision | ${REVISION} |
| ForgeSphere Config | ${CICD_CONFIG_ID} |
EOF
  )"

  printf '%s\n' "$body"
  printf '%s\n' "$body" >> "$GITHUB_STEP_SUMMARY"
}

run_step EXECUTION RELEASE_SUMMARY _summary