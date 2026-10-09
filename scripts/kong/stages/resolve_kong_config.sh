#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_resolve() {
  local addr="${CONFIG_KONNECT_ADDR:-$INPUT_KONNECT_ADDR}"
  local cp="${CONFIG_CONTROL_PLANE:-$INPUT_CONTROL_PLANE}"
  local mode="${CONFIG_DECK_MODE:-$INPUT_DECK_MODE}"
  local token="${CONFIG_KONNECT_PAT:-}"

  case "$mode" in
    apply|sync) ;;
    *) echo "Invalid deck_mode: $mode" >&2; return 1 ;;
  esac

  {
    echo "konnect_addr=$addr"
    echo "control_plane_name=$cp"
    echo "deck_mode=$mode"
    echo "konnect_token=$token"
  } >> "$GITHUB_OUTPUT"

  echo "konnect_addr=$addr"
  echo "control_plane_name=$cp"
  echo "deck_mode=$mode"
  echo "konnect_token=********"
}

run_step KONG_CONFIG RESOLVE_CONFIG _resolve