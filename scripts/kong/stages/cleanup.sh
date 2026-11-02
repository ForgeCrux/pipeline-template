#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_cleanup() {
  rm -f deck.tar.gz apply-report.json apply-stderr.txt kong-state.json combined-stderr.txt deck-result.json
  echo "Temporary files removed"
}

run_step CLEANUP CLEANUP _cleanup