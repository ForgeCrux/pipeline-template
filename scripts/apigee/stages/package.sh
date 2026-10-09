#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

package_proxy() {
  local zip="proxy.zip"
  [ "$RESOURCE_TYPE" = "apis" ] || zip="sharedflowbundle.zip"

  echo "RESOURCE_TYPE=$RESOURCE_TYPE"
  echo "BUNDLE_DIR=$BUNDLE_DIR"
  echo "ZIP_FILE=$zip"

  test -d "$BUNDLE_DIR"
  zip -r "$zip" "$BUNDLE_DIR"
  cp "$zip" "${DEPLOY_PROXY}.zip"

  echo "Artifact: ${DEPLOY_PROXY}.zip"
  ls -lh "$zip" "${DEPLOY_PROXY}.zip"
}

run_step PACKAGE PACKAGE_PROXY package_proxy