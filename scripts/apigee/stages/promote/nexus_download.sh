#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../_common.sh"

_download() {
  [ -n "${NEXUS_URL:-}" ]        || { echo "Nexus URL is not configured" >&2; return 1; }
  [ -n "${NEXUS_REPOSITORY:-}" ] || { echo "Nexus repository is not configured" >&2; return 1; }

  local artifact_name="${NEXUS_ARTIFACT_NAME:-${DEPLOY_PROXY}.zip}"
  local artifact_file="deployment-package.zip"
  local url="${NEXUS_URL%/}/repository/${NEXUS_REPOSITORY}/${DEPLOY_PROXY}/${NEXUS_VERSION}/${artifact_name}"

  echo "=========================================="
  echo "NEXUS DOWNLOAD"
  echo "=========================================="
  echo "Repository : $NEXUS_REPOSITORY"
  echo "Proxy      : $DEPLOY_PROXY"
  echo "Version    : $NEXUS_VERSION"
  echo "Artifact   : $artifact_name"
  echo "=========================================="

  local status
  status="$(curl --silent --show-error --location \
    --user "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --output "$artifact_file" \
    --write-out "%{http_code}" \
    "$url")"

  echo "Nexus HTTP Status: $status"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    rm -f "$artifact_file"
    echo "ERROR: Failed to download artifact from Nexus" >&2
    return 1
  fi

  [ -s "$artifact_file" ] || { echo "Nexus artifact is empty" >&2; return 1; }

  ls -lh "$artifact_file"

  # Validate ZIP integrity inline (no separate stage needed).
  unzip -t "$artifact_file" >/dev/null
  echo "Package integrity: OK"

  {
    echo "artifact_file=$artifact_file"
    echo "artifact_name=$artifact_name"
  } >> "$GITHUB_OUTPUT"
}

run_step NEXUS DOWNLOAD_ARTIFACT _download