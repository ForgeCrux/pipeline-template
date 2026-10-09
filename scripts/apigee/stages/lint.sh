#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# Provided by the caller workflow via steps.token-select.outputs.token.
: "${GH_LINT_TOKEN:?GH_LINT_TOKEN env var must be set by workflow}"

apigee_lint() {
  if [ -d "./apigee-linting-custom" ]; then
    npx apigeelint -s "$BUNDLE_DIR" -x ./apigee-linting-custom/rules -f table.js
  else
    echo "Skipping Apigee lint"
  fi
}

js_lint() {
  npx jslint "$BUNDLE_DIR"/**/*.js
}

_lint_body() {
  run_step LINT APIGEE_LINT apigee_lint || true
  run_step LINT JS_LINT     js_lint     || true
}

stage_run LINT "Lint" _lint_body