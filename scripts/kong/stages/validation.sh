#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_validate() {
  local missing=()
  [ -n "${CONFIG_KONNECT_PAT:-}" ]    || missing+=("CONFIG_KONNECT_PAT — kong_pat_token from ForgeSphere config")
  [ -n "${CONFIG_KONNECT_ADDR:-}" ]   || missing+=("CONFIG_KONNECT_ADDR — kong_host_url from ForgeSphere config")
  [ -n "${CONFIG_CONTROL_PLANE:-}" ]  || missing+=("CONFIG_CONTROL_PLANE — kong_control_plane from ForgeSphere config")

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "ERROR: cannot run deck — these Konnect settings are empty:" >&2
    for m in "${missing[@]}"; do
      echo "  - $m" >&2
    done
    echo "" >&2
    echo "Root cause: the 'ForgeSphere configuration stage' step did not" >&2
    echo "produce these values. Look at that step's log in this run for" >&2
    echo "the 'Kong deployment target fields:' diagnostic block." >&2
    return 1
  fi

  export KONNECT_TOKEN="$CONFIG_KONNECT_PAT"
  export KONNECT_ADDR="$CONFIG_KONNECT_ADDR"
  export CONTROL_PLANE_NAME="$CONFIG_CONTROL_PLANE"

  deck gateway validate \
    --konnect-token "$KONNECT_TOKEN" \
    --konnect-addr "$KONNECT_ADDR" \
    --konnect-control-plane-name "$CONTROL_PLANE_NAME" \
    "$KONG_CONFIG_PATH" 2>&1 | tee validate-out.txt
}

run_step KONG_VALIDATE VALIDATE _validate