#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

APP_NAME="${ARGOCD_APP_NAME_OVERRIDE:-$SERVICE_NAME}"
PROJECT="${ARGOCD_PROJECT_OVERRIDE:-${ARGOCD_PROJECT:-default}}"
REPO_URL="${GITOPS_REPO_URL:?GITOPS_REPO_URL is required from gitops stage}"

_argocd_login() {
  [ -n "${ARGOCD_SERVER:-}" ] || { echo "ERROR: ARGOCD_SERVER is empty" >&2; return 1; }

  if [ -n "${ARGOCD_TOKEN:-}" ]; then
    argocd login "$ARGOCD_SERVER" --auth-token "$ARGOCD_TOKEN" --insecure --grpc-web
  else
    [ -n "${ARGOCD_USERNAME:-}" ] && [ -n "${ARGOCD_PASSWORD:-}" ] \
      || { echo "ERROR: ArgoCD credentials are not configured" >&2; return 1; }
    argocd login "$ARGOCD_SERVER" \
      --username "$ARGOCD_USERNAME" \
      --password "$ARGOCD_PASSWORD" \
      --insecure --grpc-web
  fi
}

_argocd_add_repo() {
  local authed_repo
  authed_repo="$(echo "$REPO_URL" | sed "s#https://#https://x-access-token:${GH_TOKEN}@#")"

  argocd repo add "$REPO_URL" \
    --username "x-access-token" \
    --password "$GH_TOKEN" \
    --insecure --grpc-web --upsert 2>/dev/null || {
      echo "WARNING: repo add failed; checking if already registered"
      argocd repo list --insecure --grpc-web | grep -q "$REPO_URL" || return 1
    }
}

_argocd_create_app() {
  argocd app create "$APP_NAME" \
    --project "$PROJECT" \
    --repo "$REPO_URL" \
    --path "charts/$SERVICE_NAME" \
    --dest-server "https://kubernetes.default.svc" \
    --dest-namespace "$K8S_NAMESPACE" \
    --helm-set "replicaCount=${REPLICA_COUNT:-2}" \
    --sync-policy automated \
    --sync-option CreateNamespace=true \
    --sync-option Prune=true \
    --auto-prune \
    --self-heal \
    --upsert \
    --insecure --grpc-web
}

_argocd_body() {
  run_step ARGOCD APP_LOGIN     _argocd_login
  run_step ARGOCD APP_REPO_ADD  _argocd_add_repo
  run_step ARGOCD APP_CREATE    _argocd_create_app
}

stage_run ARGOCD "ArgoCD Application" _argocd_body