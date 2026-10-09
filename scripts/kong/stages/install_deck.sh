#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_install_deck() {
  curl -sSL \
    "https://github.com/kong/deck/releases/download/v${DECK_VERSION}/deck_${DECK_VERSION}_linux_amd64.tar.gz" \
    -o deck.tar.gz

  tar -xzf deck.tar.gz
  sudo mv deck /usr/local/bin/deck
  deck version | tee deck-install.txt
}

run_step KONG_INSTALL_DECK INSTALL_DECK _install_deck