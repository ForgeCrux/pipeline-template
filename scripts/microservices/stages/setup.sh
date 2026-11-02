#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

_install_system() {
  echo "Installing system packages..."
  sudo apt-get update
  sudo apt-get install -y jq unzip zip curl gettext-base yamllint
}

_install_k8s_tools() {
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

  echo "Installing helm..."
  curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 /tmp/get_helm.sh
  /tmp/get_helm.sh

  echo "Installing kustomize..."
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/

  echo "Installing argocd CLI..."
  curl -sSL -o /usr/local/bin/argocd \
    "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  sudo chmod +x /usr/local/bin/argocd
}

_install_hadolint() {
  echo "Installing hadolint..."
  sudo wget -qO /usr/local/bin/hadolint \
    https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
  sudo chmod +x /usr/local/bin/hadolint
}

_git_auth() {
  git config --global \
    url."https://x-access-token:${GH_TOKEN:-x}@github.com/".insteadOf \
    "https://github.com/"
  echo "Git configured"
}

_setup_body() {
  run_step SETUP INSTALL_SYSTEM   _install_system
  run_step SETUP INSTALL_K8S      _install_k8s_tools
  run_step SETUP INSTALL_HADOLINT _install_hadolint
  run_step SETUP GIT_AUTH         _git_auth
}

stage_run SETUP "Setup" _setup_body