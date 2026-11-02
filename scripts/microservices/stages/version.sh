#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_version() {
  local v
  if [ -n "${INPUT_VERSION:-}" ]; then
    v="$INPUT_VERSION"
  elif [ -f "release.properties" ] && grep -q '^version=' release.properties; then
    local base; base="$(grep '^version=' release.properties | cut -d'=' -f2)"
    v="${base}-${GITHUB_SHA:0:7}"
  else
    v="0.0.0-${GITHUB_SHA:0:7}"
  fi
  echo "version=$v" >> "$GITHUB_OUTPUT"
  echo "Version: $v"
}

run_step VERSION CALCULATE_VERSION _version