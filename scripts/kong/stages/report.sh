#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_report() {
  # Normalize JSON files.
  ( [ -s apply-report.json ] && jq -e . apply-report.json >/dev/null 2>&1 ) \
    || echo '{}' > apply-report.json
  ( [ -s kong-state.json ] && jq -e . kong-state.json >/dev/null 2>&1 ) \
    || echo '{}' > kong-state.json

  local failed_step=""
  for pair in \
    "Checkout:$OUT_CHECKOUT" \
    "Load CICD Config:$OUT_CONFIG" \
    "Install decK:$OUT_INSTALL" \
    "Validate:$OUT_VALIDATE" \
    "Deploy ($DECK_MODE):$OUT_DEPLOY"
  do
    name="${pair%%:*}"; outcome="${pair##*:}"
    if [ "$outcome" = "failure" ] && [ -z "$failed_step" ]; then
      failed_step="$name"
    fi
  done

  : > combined-stderr.txt
  [ -n "$failed_step" ] && \
    echo "Pipeline FAILED at step: $failed_step" >> combined-stderr.txt

  echo "Step outcomes: checkout=$OUT_CHECKOUT config=$OUT_CONFIG install=$OUT_INSTALL validate=$OUT_VALIDATE deploy=$OUT_DEPLOY dump=$OUT_DUMP job=$JOB_STATUS" \
    >> combined-stderr.txt
  echo "" >> combined-stderr.txt

  for pair in \
    "Install decK:deck-install.txt" \
    "Validate:validate-out.txt" \
    "Apply:apply-stderr.txt"
  do
    label="${pair%%:*}"; file="${pair##*:}"
    if [ -s "$file" ]; then
      { echo "----- $label -----"; cat "$file"; echo ""; } >> combined-stderr.txt
    fi
  done

  local apply_exit=0
  [ "$JOB_STATUS" = "failure" ] || [ "$OUT_DEPLOY" = "failure" ] && apply_exit=1

  jq -n \
    --slurpfile state kong-state.json \
    --slurpfile report apply-report.json \
    --argjson exit "$apply_exit" \
    --rawfile stderr combined-stderr.txt \
    '{
       kongState: $state[0],
       applyReport: $report[0],
       applyExitCode: $exit,
       applyStderr: $stderr
     }' > deck-result.json

  cat combined-stderr.txt

  curl -sS -X POST "$RESULT_CALLBACK_URL" \
    -H "Content-Type: application/json" \
    --data @deck-result.json \
    || echo "callback POST failed (non-fatal)"
}

run_step KONG_REPORT REPORT_RESULT _report