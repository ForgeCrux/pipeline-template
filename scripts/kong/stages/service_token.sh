#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_get_token() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
  [ -s "$GITHUB_OUTPUT" ] || { echo "GITHUB_OUTPUT is empty" >&2; return 1; }
  grep -q '^access_token=' "$GITHUB_OUTPUT" \
    || { echo "access_token missing from step output" >&2; return 1; }
}

_build_artifact_version() {
  python3 "${_SCRIPTS_DIR}/get_service_token.py"
}