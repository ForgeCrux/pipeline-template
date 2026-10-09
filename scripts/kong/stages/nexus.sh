#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_upload() {
  local artifact="kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.tar.gz"
  local checksum="${artifact}.sha256"
  local base="${NEXUS_URL%/}/${NEXUS_REPOSITORY}/kong/${DEPLOY_PROXY}/${ARTIFACT_VERSION}"

  curl --fail-with-body --silent --show-error \
    --user "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$artifact" "$base/$artifact"

  curl --fail-with-body --silent --show-error \
    --user "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$checksum" "$base/$checksum"

  echo "artifact_url=$base/$artifact" >> "$GITHUB_OUTPUT"
  echo "Nexus upload successful"
}

run_step KONG_NEXUS NEXUS_UPLOAD _upload