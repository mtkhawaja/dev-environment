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

log "INFO" "Saving logs to: $LOGFILE"
log "INFO" "Starting Ansible bootstrap script"

if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  log "ERROR" "This script must be run with sudo privileges"
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

if ! command -v ansible >/dev/null 2>&1; then
  log "ERROR" "Ansible installation failed or not found in PATH"
  exit 1
fi

ansible_version=$(ansible --version | head -n 1)
log "INFO" "Successfully installed: $ansible_version"

log "INFO" "Running ansible-pull to configure the system"
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml || {
  log "ERROR" "ansible-pull failed"
  exit 1
}

log "INFO" "Bootstrap completed successfully"
log "INFO" "Log file saved to: $LOGFILE"