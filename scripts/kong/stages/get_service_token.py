#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}

run_step KONG_SETUP GET_SERVICE_TOKEN _get_token