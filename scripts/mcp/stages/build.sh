#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_java_build() {
  case "$BUILD_TOOL" in
    maven)
      echo "Building with Maven..."
      # shellcheck disable=SC2086
      mvn -B clean package $MAVEN_ARGS
      ;;
    gradle)
      echo "Building with Gradle..."
      # shellcheck disable=SC2086
      ./gradlew clean build $GRADLE_ARGS
      ;;
    *)
      echo "ERROR: build_tool must be 'maven' or 'gradle'" >&2
      return 1
      ;;
  esac
}

_verify_jar() {
  local jar
  # shellcheck disable=SC2086
  jar="$(ls $JAR_PATH 2>/dev/null | head -1)"
  [ -n "$jar" ] || { echo "ERROR: no JAR found at '$JAR_PATH'" >&2; return 1; }
  echo "Built JAR: $jar ($(du -h "$jar" | cut -f1))"
  echo "jar_path=$jar" >> "$GITHUB_OUTPUT"
}

_docker_login() {
  if [ -n "${REGISTRY_URL:-}" ] && [ -n "${REGISTRY_USERNAME:-}" ] && [ -n "${REGISTRY_PASSWORD:-}" ]; then
    echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin
  else
    echo "Registry credentials not configured; build only"
  fi
}

_docker_build() {
  local image="${REGISTRY_URL:-localhost}/${SERVER_NAME}"
  docker build \
    --label "version=${IMAGE_TAG}" \
    --label "service=${SERVER_NAME}" \
    --label "service-type=mcp" \
    --label "commit=${GITHUB_SHA}" \
    -t "${image}:${IMAGE_TAG}" \
    -t "${image}:latest" \
    -f "$DOCKERFILE_PATH" .
}

_docker_push() {
  [ -n "${REGISTRY_URL:-}" ] || { echo "Skipping push"; return 0; }
  local image="${REGISTRY_URL}/${SERVER_NAME}"
  docker push "${image}:${IMAGE_TAG}"
  docker push "${image}:latest"
  echo "image_tag=${image}:${IMAGE_TAG}" >> "$GITHUB_OUTPUT"
}

_build_body() {
  run_step BUILD JAVA_BUILD   _java_build
  run_step BUILD VERIFY_JAR   _verify_jar
  run_step BUILD DOCKER_LOGIN _docker_login
  run_step BUILD DOCKER_BUILD _docker_build
  run_step BUILD DOCKER_PUSH  _docker_push
}

stage_run BUILD "Build & Push" _build_body
