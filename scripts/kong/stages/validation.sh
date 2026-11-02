#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_validate() {
  export KONNECT_TOKEN="${CONFIG_KONNECT_PAT:-}"
  export KONNECT_ADDR="${CONFIG_KONNECT_ADDR:-}"
  export CONTROL_PLANE_NAME="${CONFIG_CONTROL_PLANE:-}"

  deck gateway validate \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    "$KONG_CONFIG_PATH" 2>&1 | tee validate-out.txt
}

stage_run KONG_VALIDATE "Validation" _validate