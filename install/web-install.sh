#!/bin/bash
# =============================================================================
# Moonboard — Raspberry Pi Install Script
# Express API (api/index.js) + React static UI (ui/)
# Source: /boot/firmware/moonboard/web/dist
# Target OS: Raspberry Pi OS Bookworm
# =============================================================================

set -e

# Load shared config
source "$(dirname "$0")/config.sh"
optimize_low_memory

SOURCE_DIR="${SOURCE_DIR:-/boot/firmware/moonboard/web}"
NODE_VERSION="20"

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()   { echo -e "${GREEN}[✔]${NC} $1"; }
info()  { echo -e "${BLUE}[i]${NC} $1"; }
error() { echo -e "${RED}[✘]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "Please run as root: sudo bash install.sh"

echo ""
echo -e "${BLUE}==============================${NC}"
echo -e "${BLUE}  Moonboard — Pi Installer${NC}"
echo -e "${BLUE}==============================${NC}"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Verify source files exist
# -----------------------------------------------------------------------------
info "Step 1/4: Checking source files..."

[[ -f "$SOURCE_DIR/package.json" ]]      || error "Missing $SOURCE_DIR/package.json"
[[ -f "$SOURCE_DIR/src/api/index.ts" ]]  || error "Missing $SOURCE_DIR/src/api/index.ts"
[[ -f "$SOURCE_DIR/src/ui/index.tsx" ]]  || error "Missing $SOURCE_DIR/src/ui/index.tsx"

log "Source files found at $SOURCE_DIR"

# -----------------------------------------------------------------------------
# STEP 2: Install Node.js
# -----------------------------------------------------------------------------
info "Step 2/4: Checking Node.js..."

if command -v node &>/dev/null; then
  log "Node.js already installed ($(node -v)). Skipping."
else
  wait_for_apt_locks
  apt-get update -qq
  CANDIDATE=$(apt-cache policy nodejs | grep Candidate | awk '{print $2}')
  MAJOR_VER=$(echo "$CANDIDATE" | cut -d. -f1)

  if [[ "$MAJOR_VER" =~ ^[0-9]+$ ]] && [[ "$MAJOR_VER" -ge 20 ]]; then
    info "System repository has Node.js v$MAJOR_VER. Installing via apt..."
    apt-get install -y nodejs npm
  else
    info "System Node.js version ($CANDIDATE) is insufficient. Falling back to manual install..."
    ARCH=$(dpkg --print-architecture)
    if [[ "$ARCH" == "armhf" ]]; then
      info "Detected armhf. Downloading official binaries..."
      apt-get install -y curl xz-utils
      # Install Node v20.11.1 (LTS) for armv7l
      NODE_DIST="v20.11.1"
      curl -fsSL "https://nodejs.org/dist/${NODE_DIST}/node-${NODE_DIST}-linux-armv7l.tar.xz" -o node-install.tar.xz || error "Download failed"
      tar -xJf node-install.tar.xz --strip-components=1 -C /usr/local
      rm node-install.tar.xz
      ln -sf /usr/local/bin/node /usr/bin/node
    else
      info "Using NodeSource..."
      apt-get install -y curl ca-certificates
      curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - || error "NodeSource setup failed"
      apt-get install -y nodejs
    fi
  fi
  log "Node.js $(node -v) installed."
fi

# -----------------------------------------------------------------------------
# STEP 3: Copy files and install dependencies
# -----------------------------------------------------------------------------
info "Step 3/4: Installing app to $WEB_TARGET..."

if systemctl is-active --quiet "$WEB_APP_NAME" 2>/dev/null; then
  systemctl stop "$WEB_APP_NAME"
fi

# Clean target directory first (excluding existing grid_config.json, led_mapping.json, etc.)
rm -rf "$WEB_TARGET/node_modules" "$WEB_TARGET/dist"

mkdir -p "$WEB_TARGET"
if command -v rsync &>/dev/null; then
  rsync -r --exclude="node_modules" --exclude="dist" "$SOURCE_DIR/" "$WEB_TARGET/"
else
  tar --exclude="node_modules" --exclude="dist" -cf - -C "$SOURCE_DIR" . | tar -xf - -C "$WEB_TARGET"
fi

# Copy src/led/led_mapping.json to /home/moonboard_web/led_mapping.json if it doesn't already exist
if [[ ! -f "$WEB_TARGET/led_mapping.json" ]]; then
  if [[ -f "/boot/firmware/moonboard/led/led_mapping.json" ]]; then
    cp "/boot/firmware/moonboard/led/led_mapping.json" "$WEB_TARGET/led_mapping.json"
  elif [[ -f "/opt/moonboard/led/led_mapping.json" ]]; then
    cp "/opt/moonboard/led/led_mapping.json" "$WEB_TARGET/led_mapping.json"
  elif [[ -f "$(dirname "$SOURCE_DIR")/led/led_mapping.json" ]]; then
    cp "$(dirname "$SOURCE_DIR")/led/led_mapping.json" "$WEB_TARGET/led_mapping.json"
  fi
fi

chown -R "$WEB_USER":"$WEB_USER" "$WEB_TARGET"
cd "$WEB_TARGET"

# Install and build on device
sudo -u "$WEB_USER" env NODE_OPTIONS="${NODE_OPTIONS:-}" npm install
sudo -u "$WEB_USER" env NODE_OPTIONS="${NODE_OPTIONS:-}" npm run build

log "Files installed and dependencies ready."

# -----------------------------------------------------------------------------
# STEP 4: Create and start systemd service
# -----------------------------------------------------------------------------
info "Step 4/4: Setting up systemd service..."

# Copy the service file from web/service/
cp "$(dirname "$SOURCE_DIR")/service/moonboard_web.service" "/etc/systemd/system/${WEB_APP_NAME}.service"

# Update the service User to match the script configuration
sed -i "s/^User=.*/User=$WEB_USER/" "/etc/systemd/system/${WEB_APP_NAME}.service"

systemctl daemon-reload
systemctl enable "$WEB_APP_NAME"
systemctl start "$WEB_APP_NAME"

sleep 2
systemctl is-active --quiet "$WEB_APP_NAME" || error "Service failed to start. Check logs: journalctl -u $WEB_APP_NAME -n 50"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "  URL     : ${BLUE}http://$(hostname -I | awk '{print $1}'):$WEB_PORT${NC}"
echo -e "  App dir : ${BLUE}$WEB_TARGET${NC}"
echo ""
echo -e "  ${YELLOW}sudo systemctl status $WEB_APP_NAME${NC}   — status"
echo -e "  ${YELLOW}sudo systemctl restart $WEB_APP_NAME${NC}  — restart"
echo -e "  ${YELLOW}journalctl -u $WEB_APP_NAME -f${NC}        — live logs"
echo ""
