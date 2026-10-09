#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_verify_auth() {
  [ -n "${ACCESS_TOKEN:-}" ] || { echo "ERROR: ACCESS_TOKEN empty" >&2; return 1; }
  echo "Apigee access token generated successfully"
}

_verify_auth_body() {
  run_step GCP_AUTH VERIFY_AUTHENTICATION _verify_auth
}

stage_run GCP_AUTH "GCloud Login" _verify_auth_body