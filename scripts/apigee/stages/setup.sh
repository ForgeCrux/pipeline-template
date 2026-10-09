#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

install_tools() {
  echo "Installing jq, unzip and zip..."
  sudo apt-get update
  sudo apt-get install -y jq unzip zip
  echo "Required tools installed successfully"
}

github_auth() {
  git config --global \
    url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf \
    "https://github.com/"
  echo "GitHub authentication configuration completed"
}

_setup_body() {
  run_step SETUP INSTALL_TOOLS install_tools
  run_step SETUP GITHUB_AUTH    github_auth
}

stage_run SETUP "Setup" _setup_body