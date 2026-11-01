#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_push_package() {
  local artifact="${DEPLOY_PROXY}.zip"
  local version="$PACKAGE_VERSION"

  [ -f "$artifact" ]             || { echo "ERROR: $artifact not found" >&2; return 1; }
  [ -n "${NEXUS_REPOSITORY:-}" ] || { echo "ERROR: NEXUS_REPOSITORY empty" >&2; return 1; }

  local url="${NEXUS_URL%/}/repository/${NEXUS_REPOSITORY}/${DEPLOY_PROXY}/${version}/${artifact}"
  echo "Uploading to $url"

  curl --fail --show-error --silent \
    --user "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$artifact" \
    "$url"

  echo "Nexus upload successful"
}

_skip_not_configured() {
  echo "Nexus configuration not available from ForgeSphere"
  echo "Skipping Nexus upload"
}

_skip_branch_mismatch() {
  echo "Skipping Nexus upload: branch '${BRANCH_NAME:-}' does not match merge branch '${MERGE_BRANCH:-}'"
}

_nexus_body() {
  if [ -z "${NEXUS_URL:-}" ]; then
    run_step NEXUS NEXUS_NOT_CONFIGURED _skip_not_configured
    return 0
  fi

  if [ -n "${MERGE_BRANCH:-}" ] && [ "${MERGE_BRANCH}" != "${BRANCH_NAME:-}" ]; then
    run_step NEXUS NEXUS_SKIP_BRANCH_MISMATCH _skip_branch_mismatch
    return 0
  fi

  run_step NEXUS PUSH_PACKAGE _push_package
}

stage_run NEXUS "Nexus Push" _nexus_body