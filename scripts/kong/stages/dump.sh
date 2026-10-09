#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_dump() {
  deck gateway dump \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    --select-tag "$SELECT_TAG" \
    --format json \
    -o kong-state.json

  cat kong-state.json
}

run_step KONG_DUMP DUMP _dump