#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_diff() {
  deck gateway diff \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    "$KONG_CONFIG_PATH" || true
}

run_step KONG_DIFF DIFF _diff