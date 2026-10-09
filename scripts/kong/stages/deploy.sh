#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_deploy() {
  echo "Mode:          $DECK_MODE"
  echo "Control Plane: $CONTROL_PLANE_NAME"
  echo "Konnect Addr:  $KONNECT_ADDR"

  set +e
  deck gateway "$DECK_MODE" \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    --json-output \
    "$KONG_CONFIG_PATH" \
    > apply-report.json 2> apply-stderr.txt
  local rc=$?
  set -e

  cat apply-report.json || true
  cat apply-stderr.txt   || true
  return $rc
}

run_step KONG_DEPLOY DEPLOY _deploy