#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Pinned to a current 6.x release; override via SONAR_SCANNER_VERSION env if needed.
SONAR_SCANNER_VERSION="${SONAR_SCANNER_VERSION:-6.2.1.4610}"

_install_scanner() {
  if [ -n "${SONAR_SCANNER_HOME:-}" ] && [ -x "${SONAR_SCANNER_HOME}/bin/sonar-scanner" ]; then
    echo "Using cached sonar-scanner at ${SONAR_SCANNER_HOME}"
    return 0
  fi

  local install_root="${RUNNER_TOOL_CACHE:-/opt/hostedtoolcache}/sonar-scanner"
  local target="${install_root}/sonar-scanner-${SONAR_SCANNER_VERSION}"

  if [ -x "${target}/bin/sonar-scanner" ]; then
    export SONAR_SCANNER_HOME="$target"
    echo "Using pre-installed sonar-scanner: $SONAR_SCANNER_HOME"
    return 0
  fi

  mkdir -p "$install_root"
  cd "$install_root"
  echo "Downloading sonar-scanner ${SONAR_SCANNER_VERSION}..."
  curl -sSL \
    "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" \
    -o "scanner-${SONAR_SCANNER_VERSION}.zip"
  unzip -q "scanner-${SONAR_SCANNER_VERSION}.zip"
  rm -f "scanner-${SONAR_SCANNER_VERSION}.zip"
  cd - >/dev/null

  export SONAR_SCANNER_HOME="$target"
  echo "Installed sonar-scanner at $SONAR_SCANNER_HOME"
}

_run_sonar() {
  # ---- Java 21 enforcement ----------------------------------------
  if [ -z "${JAVA_HOME:-}" ] || [ ! -x "${JAVA_HOME}/bin/java" ]; then
    echo "ERROR: JAVA_HOME is not set or does not point to a Java install" >&2
    echo "  JAVA_HOME=${JAVA_HOME:-<unset>}" >&2
    return 1
  fi
  export JAVA_HOME
  export PATH="${JAVA_HOME}/bin:${PATH}"
  export SONAR_SCANNER_JAVA_EXECUTABLE="${JAVA_HOME}/bin/java"

  echo "JAVA_HOME                     : $JAVA_HOME"
  echo "command -v java               : $(command -v java)"
  java -version 2>&1 | sed 's/^/  /'

  # ---- Install / locate the CLI -----------------------------------
  _install_scanner

  # ---- Run the scanner --------------------------------------------
  export SONAR_HOST_URL SONAR_TOKEN SONAR_PROJECT_KEY
  export SONAR_SCANNER_SKIP_JRE_PROVISIONING=true

  "${SONAR_SCANNER_HOME}/bin/sonar-scanner" \
    -Dsonar.host.url="$SONAR_HOST_URL" \
    -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
    -Dsonar.sources="$BUNDLE_DIR" \
    -Dsonar.verbose=false
}

run_step SONAR SONAR_SCAN _run_sonar || true