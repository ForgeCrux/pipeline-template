#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_run_sonar() {
  # ------------------------------------------------------------------
  # Java 21 setup.
  #
  # actions/setup-java@v4 exports JAVA_HOME but the sonar-scanner-cli
  # bash launcher (5.0.1.3006) resolves java via `command -v java`,
  # which still finds the runner's Java 17. Prepend JAVA_HOME/bin to
  # PATH so every detection mechanism agrees on Java 21.
  # ------------------------------------------------------------------
  if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
    echo "ERROR: JAVA_HOME is not set or does not point to a Java install" >&2
    echo "  JAVA_HOME=${JAVA_HOME:-<unset>}" >&2
    return 1
  fi

  export JAVA_HOME
  export PATH="${JAVA_HOME}/bin:${PATH}"
  export SONAR_SCANNER_JAVA_EXECUTABLE="${JAVA_HOME}/bin/java"

  echo "JAVA_HOME                       : $JAVA_HOME"
  echo "command -v java                 : $(command -v java)"
  echo "SONAR_SCANNER_JAVA_EXECUTABLE   : $SONAR_SCANNER_JAVA_EXECUTABLE"
  echo "java -version:"
  java -version 2>&1 | sed 's/^/  /'

  # ------------------------------------------------------------------
  # SonarScanner invocation.
  #
  # Do not let the scanner try to auto-provision its own JRE — we have
  # Java 21 locally and the provisioning endpoint is not needed.
  # ------------------------------------------------------------------
  export SONAR_TOKEN
  export SONAR_HOST_URL
  export SONAR_PROJECT_KEY
  export SONAR_SCANNER_SKIP_JRE_PROVISIONING=true

  npx --yes sonarqube-scanner@3 \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.sources="$BUNDLE_DIR" \
    -Dsonar.verbose=true
}

run_step SONAR SONAR_SCAN _run_sonar || true