#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_cleanup() {
  rm -rf /tmp/kustomize-output.yaml /tmp/create-repo.json cicd-config.json || true
  if [ -n "${REGISTRY_URL:-}" ]; then
    docker logout "$REGISTRY_URL" 2>/dev/null || true
  fi
  echo "Cleanup complete"
}

# Cleanup is not a stage_run in the Apigee pipeline — direct run_step.
run_step CLEANUP CLEANUP _cleanup