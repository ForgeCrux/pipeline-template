#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_validate() {
  echo "Address:       $KONNECT_ADDR"
  echo "Control Plane: $CONTROL_PLANE_NAME"
  echo "Mode:          $DECK_MODE"
  echo "Token:         ********"

  deck gateway validate \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    "$KONG_CONFIG_PATH" \
    2>&1 | tee validate-out.txt
}

run_step KONG_VALIDATE VALIDATE _validate