#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_latest_revision() {
  local token="${TOKEN:-${ACCESS_TOKEN:-}}"
  if [ -z "$token" ]; then
    echo "ERROR: no access token available (TOKEN and ACCESS_TOKEN are both empty)" >&2
    echo "  Confirm the GCP auth step succeeded and passed ACCESS_TOKEN to this step." >&2
    return 1
  fi

  local rev
  rev="$(curl --silent --show-error \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/${RESOURCE_TYPE}/${DEPLOY_PROXY}/revisions" \
    | jq -r 'map(tonumber) | max')"

  if [ -z "$rev" ] || [ "$rev" = "null" ]; then
    echo "ERROR: Unable to determine revision (API returned no revisions)" >&2
    return 1
  fi

  echo "revision=$rev" >> "$GITHUB_OUTPUT"
  echo "Latest revision: $rev"
}

_revision_body() {
  run_step REVISION GET_LATEST_REVISION _get_latest_revision
}

stage_run REVISION "Revision" _revision_body