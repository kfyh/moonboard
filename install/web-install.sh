#!/bin/bash
# =============================================================================
# Moonboard — Raspberry Pi Install Script
# Express API (api/index.js) + React static UI (ui/)
# Source: /boot/firmware/moonboard/web/dist
# Target OS: Raspberry Pi OS Bookworm
# =============================================================================

set -e

APP_NAME="moonboard"
APP_DIR="/home/pi/$APP_NAME"
SOURCE_DIR="/boot/firmware/moonboard/web/dist"
APP_PORT=3000
NODE_VERSION="20"
SERVICE_USER="pi"

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

[[ -d "$SOURCE_DIR/api" ]]           || error "Missing $SOURCE_DIR/api"
[[ -f "$SOURCE_DIR/api/index.js" ]]  || error "Missing $SOURCE_DIR/api/index.js"
[[ -d "$SOURCE_DIR/ui" ]]            || error "Missing $SOURCE_DIR/ui"
[[ -f "$SOURCE_DIR/ui/index.html" ]] || error "Missing $SOURCE_DIR/ui/index.html"

log "Source files found at $SOURCE_DIR"

# -----------------------------------------------------------------------------
# STEP 2: Install Node.js
# -----------------------------------------------------------------------------
info "Step 2/4: Checking Node.js..."

if command -v node &>/dev/null; then
  log "Node.js already installed ($(node -v)). Skipping."
else
  apt-get update -qq
  apt-get install -y curl ca-certificates
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  apt-get install -y nodejs
  log "Node.js $(node -v) installed."
fi

# -----------------------------------------------------------------------------
# STEP 3: Copy files and install dependencies
# -----------------------------------------------------------------------------
info "Step 3/4: Installing app to $APP_DIR..."

if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
  systemctl stop "$APP_NAME"
fi

mkdir -p "$APP_DIR"
cp -r "$SOURCE_DIR/api" "$APP_DIR/"
cp -r "$SOURCE_DIR/ui"  "$APP_DIR/"

# Generate a minimal package.json if one isn't bundled in dist
if [[ ! -f "$SOURCE_DIR/package.json" ]]; then
  cat > "$APP_DIR/package.json" <<EOF
{
  "name": "moonboard",
  "version": "1.0.0",
  "main": "api/index.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
fi

chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"
cd "$APP_DIR"
sudo -u "$SERVICE_USER" npm install --omit=dev

log "Files installed and dependencies ready."

# -----------------------------------------------------------------------------
# STEP 4: Create and start systemd service
# -----------------------------------------------------------------------------
info "Step 4/4: Setting up systemd service..."

cat > "/etc/systemd/system/${APP_NAME}.service" <<EOF
[Unit]
Description=Moonboard Express App
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node $APP_DIR/api/index.js
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$APP_NAME
Environment=NODE_ENV=production
Environment=PORT=$APP_PORT
Environment=UI_DIR=$APP_DIR/ui

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$APP_NAME"
systemctl start "$APP_NAME"

sleep 2
systemctl is-active --quiet "$APP_NAME" || error "Service failed to start. Check logs: journalctl -u $APP_NAME -n 50"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "  URL     : ${BLUE}http://$(hostname -I | awk '{print $1}'):$APP_PORT${NC}"
echo -e "  App dir : ${BLUE}$APP_DIR${NC}"
echo ""
echo -e "  ${YELLOW}sudo systemctl status $APP_NAME${NC}   — status"
echo -e "  ${YELLOW}sudo systemctl restart $APP_NAME${NC}  — restart"
echo -e "  ${YELLOW}journalctl -u $APP_NAME -f${NC}        — live logs"
echo ""
