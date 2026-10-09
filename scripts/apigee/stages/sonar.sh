#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_run_sonar() {
  export SONAR_TOKEN SONAR_HOST_URL SONAR_PROJECT_KEY

  # Skip JRE auto-provisioning (that endpoint returns 403 in this env).
  export SONAR_SCANNER_SKIP_JRE_PROVISIONING=true

  # Force the scanner to use the Java 21 installed by actions/setup-java.
  if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
    export SONAR_SCANNER_JAVA_EXECUTABLE="${JAVA_HOME}/bin/java"
    echo "Using Java from JAVA_HOME: $SONAR_SCANNER_JAVA_EXECUTABLE"
  fi

  npx --yes sonarqube-scanner@3 \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.sources="$BUNDLE_DIR"
}

run_step SONAR SONAR_SCAN _run_sonar || true