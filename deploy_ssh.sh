#!/bin/bash

# =============================================================================
# Moonboard — SSH Deploy Script
# Copies files to the Raspberry Pi over SSH and restarts services.
# =============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✘]${NC} $1"; exit 1; }

# Default configuration
DEFAULT_HOST="moonboard-pi.local"
DEFAULT_USER="admin"

# Read connection info
read -p "Enter Raspberry Pi Host/IP [$DEFAULT_HOST]: " HOST
HOST=${HOST:-$DEFAULT_HOST}

read -p "Enter SSH Username [$DEFAULT_USER]: " USER
USER=${USER:-$DEFAULT_USER}

TARGET="$USER@$HOST"

# Setup SSH connection sharing (multiplexing) to support password auth without multiple prompts
SSH_SOCKET="/tmp/ssh_mux_${HOST}_${USER}"
SSH_OPTS=(-o "ControlMaster=auto" -o "ControlPath=$SSH_SOCKET" -o "ControlPersist=600" -o "ConnectTimeout=5" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")

cleanup_ssh_mux() {
    info "Closing master SSH connection..."
    ssh "${SSH_OPTS[@]}" -O exit "$TARGET" 2>/dev/null || true
}
trap cleanup_ssh_mux EXIT

info "Verifying SSH connection to $TARGET (you may need to enter your SSH password)..."
# We only redirect stdout so the password prompt from ssh on stderr/tty is visible
if ! ssh "${SSH_OPTS[@]}" "$TARGET" "true"; then
    error "Could not connect to $TARGET. Please check IP/Host, username, and SSH setup."
fi
log "Connection successful!"

# Optional web build
read -p "Build React Web UI locally first? (y/n) [n]: " BUILD_WEB
BUILD_WEB=${BUILD_WEB:-n}

if [[ "$BUILD_WEB" =~ ^[Yy]$ ]]; then
    info "Building Web UI..."
    cd src/web
    npm run build
    cd ../..
fi

# Create remote temp deploy directory
info "Preparing temp directory on Raspberry Pi..."
ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p /tmp/moonboard_deploy/web"

# Rsync files to the RPi
info "Copying files to $TARGET:/tmp/moonboard_deploy/..."

# Sync python code and installation scripts
rsync -avz --delete \
    -e "ssh -o ControlPath=$SSH_SOCKET" \
    --exclude="*__pycache__*" \
    src/ble src/led install \
    "$TARGET:/tmp/moonboard_deploy/"

# Sync web build and configuration files
if [[ -d "src/web/dist" ]]; then
    rsync -avz --delete \
        -e "ssh -o ControlPath=$SSH_SOCKET" \
        src/web/dist src/web/service src/web/package.json \
        "$TARGET:/tmp/moonboard_deploy/web/"
else
    warn "Local 'src/web/dist' not found. Web files will not be updated on the Pi."
fi

# Execute update on the Pi
info "Executing installer on Raspberry Pi (you may be prompted for your sudo password)..."
ssh "${SSH_OPTS[@]}" -t "$TARGET" "sudo /tmp/moonboard_deploy/install/update.sh"

# Cleanup
info "Cleaning up temp files on Pi..."
ssh "${SSH_OPTS[@]}" "$TARGET" "rm -rf /tmp/moonboard_deploy"

log "Deployment and service restarts completed successfully!"
