#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_cleanup() {
  rm -f apigee-config.json cicd-config.json proxy.zip sharedflowbundle.zip
  echo "Temporary configuration removed"
}

run_step CLEANUP CLEANUP _cleanup