#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_import_proxy() {
  local zip="proxy.zip"
  [ "$RESOURCE_TYPE" = "apis" ] || zip="sharedflowbundle.zip"

  local url="https://apigee.googleapis.com/v1/organizations/${APIGEE_ORG}/${RESOURCE_TYPE}?action=import&name=${DEPLOY_PROXY}"

  local response
  response="$(curl --silent --show-error --write-out '\nHTTP_STATUS:%{http_code}\n' \
    -X POST -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -F "file=@${zip}" "$url")"

  local status
  status="$(echo "$response" | grep HTTP_STATUS | cut -d':' -f2)"

  if [ "$status" -ne 200 ]; then
    echo "Import failed:"; echo "$response"; return 1
  fi
  echo "Import successful"
}

_import_body() {
  run_step IMPORT IMPORT_PROXY _import_proxy
}

stage_run IMPORT "Import" _import_body