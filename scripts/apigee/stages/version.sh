#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_calculate_version() {
  local version
  if [ -n "$INPUT_VERSION" ]; then
    version="$INPUT_VERSION"
  else
    local base; base="$(grep '^version=' release.properties | cut -d'=' -f2)"
    local sha;  sha="$(git rev-parse --short HEAD)"
    version="${base}-${sha}"
  fi
  echo "Version: $version"
  echo "version=$version" >> "$GITHUB_OUTPUT"
}

run_step VERSION CALCULATE_VERSION _calculate_version