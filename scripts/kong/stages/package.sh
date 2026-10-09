#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_package() {
  mkdir -p nexus-artifact
  cp kong-state.json nexus-artifact/

  cat > nexus-artifact/metadata.json <<EOF
{
  "artifactType": "kong-konnect",
  "deployProxy": "${DEPLOY_PROXY}",
  "controlPlane": "${CONTROL_PLANE_NAME}",
  "version": "${ARTIFACT_VERSION}",
  "githubRepository": "${GITHUB_REPOSITORY}",
  "githubRunId": "${GITHUB_RUN_ID}",
  "githubSha": "${GITHUB_SHA}",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  tar -czf "kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.tar.gz" \
    -C nexus-artifact kong-state.json metadata.json

  sha256sum "kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.tar.gz" \
    > "kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.sha256"

  ls -lh "kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.tar.gz" \
         "kong-${DEPLOY_PROXY}-${ARTIFACT_VERSION}.sha256"
}

run_step KONG_PACKAGE PACKAGE _package