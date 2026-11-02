#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_diff() {
  export KONNECT_TOKEN="${CONFIG_KONNECT_PAT:-}"
  export KONNECT_ADDR="${CONFIG_KONNECT_ADDR:-}"
  export CONTROL_PLANE_NAME="${CONFIG_CONTROL_PLANE:-}"

  deck gateway diff \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    "$KONG_CONFIG_PATH" || true
}

run_step DIFF DIFF _diff