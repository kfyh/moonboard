#!/bin/bash

# =============================================================================
# Moonboard — Manual Update Script
# Updates Core (BLE/LED) and Web files from current directory, then restarts services.
# Usage: sudo ./install/update.sh
# =============================================================================

set -euo pipefail

# Determine directories based on the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load Shared Configuration
source "$SCRIPT_DIR/config.sh"

# Colors for output
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo $0"
   exit 1
fi

# 1. Update Core Files (BLE, LED, Logic)
info "Updating Core files to $INSTALL_TARGET..."
mkdir -p "$INSTALL_TARGET"
# Copy contents of repo root to target, updating only changed files
cp -r "$REPO_ROOT/." "$INSTALL_TARGET/"

# Ensure ownership (assuming 'pi' for core services or fallback to current SUDO_USER)
CORE_USER=$(id -nu 1000 2>/dev/null || echo "pi")
chown -R "$CORE_USER":"$CORE_USER" "$INSTALL_TARGET"
log "Core files updated."

# 2. Update Web Files
info "Updating Web files to $WEB_TARGET..."
if [[ -d "$REPO_ROOT/web/dist" ]]; then
    cp -r "$REPO_ROOT/web/dist/api" "$WEB_TARGET/"
    cp -r "$REPO_ROOT/web/dist/ui"  "$WEB_TARGET/"
    chown -R "$WEB_USER":"$WEB_USER" "$WEB_TARGET"
    log "Web files updated."
else
    echo "Warning: Web dist folder ($REPO_ROOT/web/dist) not found. Skipping web update."
fi

# 3. Restart Services
info "Restarting services..."
systemctl restart "$BLE_SERVICE" "$LED_SERVICE" "$WEB_SERVICE"

log "Update complete and services restarted!"