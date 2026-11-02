#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_dockerfile_lint() {
  hadolint "$DOCKERFILE_PATH" || return 1
}

_helm_lint() {
  [ "$DEPLOY_STRATEGY" = "helm" ] || { echo "Skipping (not helm)"; return 0; }
  helm lint "$HELM_CHART_PATH"
}

_kustomize_lint() {
  [ "$DEPLOY_STRATEGY" = "kustomize" ] || { echo "Skipping (not kustomize)"; return 0; }
  kustomize build "$KUSTOMIZE_PATH" > /tmp/kustomize-output.yaml
  yamllint /tmp/kustomize-output.yaml || true
  echo "Kustomize build OK"
}

_yaml_lint() {
  [ -d ".github/workflows" ] && yamllint .github/workflows/ || true
}

_lint_body() {
  run_step_soft LINT DOCKERFILE_LINT _dockerfile_lint
  run_step_soft LINT HELM_LINT       _helm_lint
  run_step_soft LINT KUSTOMIZE_LINT  _kustomize_lint
  run_step_soft LINT YAML_LINT       _yaml_lint
}

stage_run LINT "Lint" _lint_body