#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_apigee_lint() {
  if [ -d "./apigee-linting-custom" ]; then
    npx apigeelint -s "$BUNDLE_DIR" -x ./apigee-linting-custom/rules -f table.js
  else
    echo "Skipping Apigee lint — apigee-linting-custom/ not present"
    echo "  (GH_LINT_TOKEN set: ${GH_LINT_TOKEN:+yes}${GH_LINT_TOKEN:-no})"
  fi
}

_js_lint() {
  npx jslint "$BUNDLE_DIR"/**/*.js
}

_lint_body() {
  run_step LINT APIGEE_LINT _apigee_lint || true
  run_step LINT JS_LINT     _js_lint     || true
}

stage_run LINT "Lint" _lint_body