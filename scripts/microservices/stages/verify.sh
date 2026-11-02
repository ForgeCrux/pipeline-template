#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_gcp_auth() {
  [ -n "${WORKLOAD_IDENTITY_PROVIDER:-}" ] && [ -n "${SERVICE_ACCOUNT:-}" ] \
    || { echo "ERROR: GCP auth not configured" >&2; return 1; }
  echo "$WORKLOAD_IDENTITY_PROVIDER" | grep -q "projects/" \
    || { echo "ERROR: workload_identity_provider malformed" >&2; return 1; }
  # google-github-actions/auth already ran at the workflow level; gcloud picks
  # up credentials via GOOGLE_APPLICATION_CREDENTIALS.
  gcloud auth list
}

_gke_creds() {
  gcloud container clusters get-credentials "$K8S_CLUSTER" --location "${GKE_LOCATION:-us-central1}"
}

_rollout() {
  kubectl -n "$K8S_NAMESPACE" rollout status "deployment/$SERVICE_NAME" --timeout=300s
}

_health_check() {
  local timeout="${HEALTH_CHECK_TIMEOUT:-120}"
  kubectl -n "$K8S_NAMESPACE" port-forward "service/$SERVICE_NAME" 8080:80 &
  local pf=$!
  trap 'kill $pf 2>/dev/null || true' EXIT

  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if curl -sf "http://localhost:8080${HEALTH_CHECK_PATH}" >/dev/null; then
      echo "Health check passed"
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "ERROR: health check failed after ${timeout}s" >&2
  kubectl -n "$K8S_NAMESPACE" get pods -l "app=$SERVICE_NAME"
  return 1
}

_verify_body() {
  run_step VERIFY GCP_AUTH     _gcp_auth
  run_step VERIFY GKE_CREDS    _gke_creds
  run_step VERIFY ROLLOUT      _rollout
  run_step VERIFY HEALTH_CHECK _health_check
}

stage_run VERIFY "Verify" _verify_body