#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_install_deck() {
  curl -sSL "https://github.com/kong/deck/releases/download/v${DECK_VERSION}/deck_${DECK_VERSION}_linux_amd64.tar.gz" -o deck.tar.gz
  tar -xzf deck.tar.gz
  sudo mv deck /usr/local/bin/deck
  deck version | tee deck-install.txt
}

_resolve_flow() {
  export RAW_FLOW_CHANGE_ID="${RAW_FLOW_CHANGE_ID:-}"
  bash "${_KONG_DIR}/resolve_flow_change_id.sh"
  if [ -f "$GITHUB_ENV" ]; then
    export $(grep -v '^#' "$GITHUB_ENV" | xargs) 2>/dev/null || true
  fi
}

_setup_body() {
  run_step SETUP INSTALL_DECK _install_deck
  run_step SETUP RESOLVE_FLOW_ID _resolve_flow
}
stage_run SETUP "Setup" _setup_body