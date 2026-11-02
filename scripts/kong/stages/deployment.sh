#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_deploy() {
  export KONNECT_TOKEN="${CONFIG_KONNECT_PAT:-}"
  export KONNECT_ADDR="${CONFIG_KONNECT_ADDR:-}"
  export CONTROL_PLANE_NAME="${CONFIG_CONTROL_PLANE:-}"
  export DECK_MODE="${CONFIG_DECK_MODE:-apply}"

  set +e
  deck gateway "$DECK_MODE" \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    --json-output \
    "$KONG_CONFIG_PATH" > apply-report.json 2> apply-stderr.txt
  local rc=$?
  set -e

  cat apply-report.json || true
  cat apply-stderr.txt || true
  return $rc
}

run_step DEPLOYMENT DEPLOY _deploy