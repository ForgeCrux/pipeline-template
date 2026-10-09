#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_nexus_body() {
  if [ -z "${NEXUS_URL:-}" ]; then
    run_step NEXUS NEXUS_NOT_CONFIGURED bash -c \
      'echo "Nexus configuration not available from ForgeSphere"; echo "Skipping Nexus upload"'
    return 0
  fi

  if [ "${MERGE_BRANCH:-}" != "${BRANCH_NAME:-}" ]; then
    echo "Skipping Nexus upload; merge_branch '$MERGE_BRANCH' != branch '$BRANCH_NAME'"
    return 0
  fi

  run_step NEXUS PUSH_PACKAGE _push_package
}

_push_package() {
  local artifact="${DEPLOY_PROXY}.zip"
  local version="$PACKAGE_VERSION"

  [ -f "$artifact" ] || { echo "ERROR: $artifact not found" >&2; return 1; }
  [ -n "$NEXUS_REPOSITORY" ] || { echo "ERROR: NEXUS_REPOSITORY empty" >&2; return 1; }

  local url="${NEXUS_URL%/}/repository/${NEXUS_REPOSITORY}/${DEPLOY_PROXY}/${version}/${artifact}"
  echo "Uploading to $url"

  curl --fail --show-error --silent \
    --user "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "$artifact" \
    "$url"

  echo "Nexus upload successful"
}

stage_run NEXUS "Nexus Push" _nexus_body