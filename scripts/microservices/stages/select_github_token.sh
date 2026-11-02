#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_select() {
  if [ -n "${APP_TOKEN:-}" ]; then
    echo "Using GitHub App token"
    echo "token=$APP_TOKEN" >> "$GITHUB_OUTPUT"
  else
    echo "Using GH_TOKEN"
    echo "token=${GH_TOKEN:-}" >> "$GITHUB_OUTPUT"
  fi
}

run_step SETUP SELECT_GITHUB_TOKEN _select