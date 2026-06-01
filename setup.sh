#!/usr/bin/env bash

set -e
set -o pipefail

LOG_DIR="${HOME}/.ansible-dev-env-bootstrap"
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"

log() {
  local level=$1
  local message=$2
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $message" | tee -a "$LOGFILE"
}

REPO_URL="https://github.com/mtkhawaja/dev-environment.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "INFO" "Saving logs to: $LOGFILE"
log "INFO" "Starting Ansible bootstrap script"

OS="$(uname -s)"
log "INFO" "Detected OS: $OS"

install_ansible_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    log "INFO" "Homebrew not found; installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || { log "ERROR" "Failed to install Homebrew"; exit 1; }
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  log "INFO" "Installing Ansible via Homebrew"
  brew install ansible || { log "ERROR" "Failed to install Ansible via Homebrew"; exit 1; }
}

install_ansible_linux() {
  if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    log "ERROR" "This script must be run with sudo privileges on Linux"
    exit 1
  fi
  log "INFO" "Updating package lists"
  sudo apt update || { log "ERROR" "Failed to update package lists"; exit 1; }
  log "INFO" "Installing software-properties-common"
  sudo apt install -y software-properties-common || { log "ERROR" "Failed to install software-properties-common"; exit 1; }
  log "INFO" "Adding Ansible repository"
  sudo add-apt-repository --yes --update ppa:ansible/ansible || { log "ERROR" "Failed to add Ansible repository"; exit 1; }
  log "INFO" "Installing Ansible"
  sudo apt install -y ansible || { log "ERROR" "Failed to install Ansible"; exit 1; }
}

case "$OS" in
  Darwin) install_ansible_macos ;;
  Linux)  install_ansible_linux ;;
  *) log "ERROR" "Unsupported OS: $OS"; exit 1 ;;
esac

if ! command -v ansible >/dev/null 2>&1; then
  log "ERROR" "Ansible installation failed or not found in PATH"
  exit 1
fi

ansible_version=$(ansible --version | head -n 1)
log "INFO" "Successfully installed: $ansible_version"

log "INFO" "Installing required Ansible collections"
if [[ -f "${SCRIPT_DIR}/requirements.yml" ]]; then
  ansible-galaxy collection install -r "${SCRIPT_DIR}/requirements.yml" \
    || { log "ERROR" "Failed to install Ansible collections"; exit 1; }
else
  ansible-galaxy collection install community.general \
    || { log "ERROR" "Failed to install community.general"; exit 1; }
fi

log "INFO" "Running ansible-pull to configure the system"
ansible-pull -U "$REPO_URL" -i localhost, local.yaml || {
  log "ERROR" "ansible-pull failed"
  exit 1
}

log "INFO" "Bootstrap completed successfully"
log "INFO" "Log file saved to: $LOGFILE"
