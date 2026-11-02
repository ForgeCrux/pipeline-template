#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_validate_strategy() {
  case "$DEPLOY_STRATEGY" in
    helm|kustomize) echo "Strategy: $DEPLOY_STRATEGY" ;;
    *) echo "ERROR: deploy_strategy must be helm or kustomize (got '$DEPLOY_STRATEGY')" >&2; return 1 ;;
  esac
}

_validate_dockerfile() {
  [ -f "$DOCKERFILE_PATH" ] \
    || { echo "ERROR: Dockerfile not found at $DOCKERFILE_PATH" >&2; return 1; }
  echo "Dockerfile found: $DOCKERFILE_PATH"
}

_validate_manifests() {
  if [ "$DEPLOY_STRATEGY" = "helm" ]; then
    [ -f "$HELM_CHART_PATH/Chart.yaml" ] \
      || { echo "ERROR: Chart.yaml missing at $HELM_CHART_PATH" >&2; return 1; }
    echo "Helm chart: $HELM_CHART_PATH"
  else
    [ -f "$KUSTOMIZE_PATH/kustomization.yaml" ] \
      || { echo "ERROR: kustomization.yaml missing at $KUSTOMIZE_PATH" >&2; return 1; }
    echo "Kustomize overlay: $KUSTOMIZE_PATH"
  fi
}

_validate_release_properties() {
  if [ -f "release.properties" ] && grep -q '^version=' release.properties; then
    echo "release.properties version: $(grep '^version=' release.properties | cut -d'=' -f2)"
  else
    echo "release.properties not found or missing version (optional)"
  fi
}

_validation_body() {
  run_step VALIDATION VALIDATE_STRATEGY          _validate_strategy
  run_step VALIDATION VALIDATE_DOCKERFILE        _validate_dockerfile
  run_step VALIDATION VALIDATE_MANIFESTS         _validate_manifests
  run_step VALIDATION VALIDATE_RELEASE_PROPERTIES _validate_release_properties
}

stage_run VALIDATION "Validation" _validation_body