#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_verify() {
  export KONNECT_TOKEN="${CONFIG_KONNECT_PAT:-}"
  export KONNECT_ADDR="${CONFIG_KONNECT_ADDR:-}"
  export CONTROL_PLANE_NAME="${CONFIG_CONTROL_PLANE:-}"

  deck gateway dump \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    --select-tag "$SELECT_TAG" \
    --format json -o kong-state.json
  cat kong-state.json
}

stage_run KONG_DUMP "Verify" _verify