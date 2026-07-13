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
optimize_low_memory

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

if [[ -d "$REPO_ROOT/src/web" ]]; then
    WEB_SRC="$REPO_ROOT/src/web"
elif [[ -d "$REPO_ROOT/web" ]]; then
    WEB_SRC="$REPO_ROOT/web"
else
    WEB_SRC=""
fi

if [[ -n "$WEB_SRC" ]]; then
    if systemctl is-active --quiet "$WEB_SERVICE" 2>/dev/null; then
        systemctl stop "$WEB_SERVICE"
    fi

    rm -rf "$WEB_TARGET/node_modules" "$WEB_TARGET/dist"
    mkdir -p "$WEB_TARGET"
    if command -v rsync &>/dev/null; then
        rsync -r --exclude="node_modules" --exclude="dist" "$WEB_SRC/" "$WEB_TARGET/"
    else
        tar --exclude="node_modules" --exclude="dist" -cf - -C "$WEB_SRC" . | tar -xf - -C "$WEB_TARGET"
    fi

    if [[ ! -f "$WEB_TARGET/led_mapping.json" ]]; then
        if [[ -f "$REPO_ROOT/src/led/led_mapping.json" ]]; then
            cp "$REPO_ROOT/src/led/led_mapping.json" "$WEB_TARGET/led_mapping.json"
        elif [[ -f "$INSTALL_TARGET/led/led_mapping.json" ]]; then
            cp "$INSTALL_TARGET/led/led_mapping.json" "$WEB_TARGET/led_mapping.json"
        fi
    fi

    chown -R "$WEB_USER":"$WEB_USER" "$WEB_TARGET"
    
    cd "$WEB_TARGET"
    sudo -u "$WEB_USER" env NODE_OPTIONS="${NODE_OPTIONS:-}" npm install
    sudo -u "$WEB_USER" env NODE_OPTIONS="${NODE_OPTIONS:-}" npm run build
    log "Web files updated and compiled."
else
    echo "Warning: Web source folder not found in src/web or web. Skipping web update."
fi

# 3. Restart Services (only if they are installed)
info "Restarting services..."
for svc in "$BLE_SERVICE" "$LED_SERVICE" "$WEB_SERVICE"; do
    if [[ $(systemctl show -p LoadState "$svc" --value) != "not-found" ]]; then
        info "  Restarting $svc..."
        systemctl restart "$svc"
    else
        echo "  Service $svc is not installed yet. Skipping restart."
    fi
done

log "Update complete and services restarted!"