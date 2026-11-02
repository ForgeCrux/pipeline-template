#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_run_sonar() {
  [ -n "${SONAR_HOST_URL:-}" ] && [ -n "${SONAR_TOKEN:-}" ] && [ -n "${SONAR_PROJECT_KEY:-}" ] \
    || { echo "Sonar configuration incomplete; skipping" && return 0; }

  docker run --rm \
    -e SONAR_HOST_URL="$SONAR_HOST_URL" \
    -e SONAR_TOKEN="$SONAR_TOKEN" \
    -v "${PWD}:/usr/src" \
    -w /usr/src \
    sonarsource/sonar-scanner-cli \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.host.url="$SONAR_HOST_URL"
}

_sonar_body() {
  run_step_soft SONAR SONAR_SCAN _run_sonar
}

stage_run SONAR "Sonar" _sonar_body