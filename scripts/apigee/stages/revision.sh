#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_latest_revision() {
  local rev
  rev="$(curl --silent --show-error \
    -H "Authorization: Bearer ${TOKEN}" \
    "https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/${RESOURCE_TYPE}/${DEPLOY_PROXY}/revisions" \
    | jq -r 'map(tonumber) | max')"

  [ -n "$rev" ] && [ "$rev" != "null" ] || { echo "Unable to determine revision" >&2; return 1; }

  echo "revision=$rev" >> "$GITHUB_OUTPUT"
  echo "Latest revision: $rev"
}

_revision_body() {
  run_step REVISION GET_LATEST_REVISION _get_latest_revision
}

stage_run REVISION "Revision" _revision_body