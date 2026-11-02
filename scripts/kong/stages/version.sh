#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_version() {
  local version
  if [ -n "${INPUT_VERSION:-}" ]; then
    version="$INPUT_VERSION"
  else
    version="$(date -u +%Y.%m.%d.%H%M%S)-${GITHUB_SHA::7}"
  fi
  echo "version=$version" >> "$GITHUB_OUTPUT"
  echo "Artifact version: $version"
}

run_step VERSION CALCULATE_VERSION _version