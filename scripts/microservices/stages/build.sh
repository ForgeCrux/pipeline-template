#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_docker_login() {
  if [ -n "${REGISTRY_URL:-}" ] && [ -n "${REGISTRY_USERNAME:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
    echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin
  else
    echo "Registry credentials not configured; build only, no push"
  fi
}

_docker_build() {
  local image="${REGISTRY_URL:-localhost}/${SERVICE_NAME}"
  docker build \
    --label "version=${IMAGE_TAG}" \
    --label "service=${SERVICE_NAME}" \
    --label "commit=${GITHUB_SHA}" \
    -t "${image}:${IMAGE_TAG}" \
    -t "${image}:latest" \
    -f "$DOCKERFILE_PATH" .
}

_docker_push() {
  [ -n "${REGISTRY_URL:-}" ] || { echo "Skipping push"; return 0; }
  local image="${REGISTRY_URL}/${SERVICE_NAME}"
  docker push "${image}:${IMAGE_TAG}"
  docker push "${image}:latest"
  echo "image_tag=${image}:${IMAGE_TAG}" >> "$GITHUB_OUTPUT"
}

_build_body() {
  run_step BUILD DOCKER_LOGIN _docker_login
  run_step BUILD DOCKER_BUILD _docker_build
  run_step BUILD DOCKER_PUSH  _docker_push
}

stage_run BUILD "Build & Push" _build_body