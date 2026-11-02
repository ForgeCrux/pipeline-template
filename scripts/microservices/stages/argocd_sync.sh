#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP_NAME="${ARGOCD_APP_NAME_OVERRIDE:-$SERVICE_NAME}"

_sync() {
  argocd app sync "$APP_NAME" --insecure --grpc-web --timeout 300
}

_wait_healthy() {
  argocd app wait "$APP_NAME" --health --timeout 300 --insecure --grpc-web
}

_argocd_sync_body() {
  run_step ARGOCD_SYNC SYNC         _sync
  run_step ARGOCD_SYNC WAIT_HEALTHY _wait_healthy
}

stage_run ARGOCD_SYNC "ArgoCD Sync" _argocd_sync_body