#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_run_sonar() {
  # sonar-scanner-cli reads SONAR_TOKEN / SONAR_HOST_URL from env.
  # Falling back to a project properties file is also supported.
  export SONAR_TOKEN
  export SONAR_HOST_URL
  export SONAR_PROJECT_KEY

  # Use sonar-scanner directly — do NOT use `npx sonarqube-scanner`,
  # that npm wrapper does not reliably forward -Dsonar.token to the
  # scanner-cli, and its bundled commander requires Node >= 20.
  npx --yes sonarqube-scanner@3 \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.sources="$BUNDLE_DIR" \
    -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
}

run_step SONAR SONAR_SCAN _run_sonar || true