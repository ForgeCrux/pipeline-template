#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

validate_resource_type() {
  if [[ "$RESOURCE_TYPE" != "apis" && "$RESOURCE_TYPE" != "sharedflows" ]]; then
    echo "ERROR: Invalid resourcetype: $RESOURCE_TYPE" >&2
    return 1
  fi
  echo "Resource type: $RESOURCE_TYPE"
}

validate_release_properties() {
  [ -f release.properties ] || { echo "ERROR: release.properties not found" >&2; return 1; }
  grep -q '^version=' release.properties || { echo "ERROR: version missing" >&2; return 1; }
  echo "Base version: $(grep '^version=' release.properties | cut -d'=' -f2)"
}

_validation_body() {
  run_step VALIDATION VALIDATE_RESOURCE_TYPE       validate_resource_type
  run_step VALIDATION VALIDATE_RELEASE_PROPERTIES  validate_release_properties
}

stage_run VALIDATION "Validation" _validation_body