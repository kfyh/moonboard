#!/bin/bash

# --- Core Configuration (BLE & LED) ---
INSTALL_TARGET="/opt/moonboard"
BLE_SERVICE="com.moonboard.service"
LED_SERVICE="moonboard_led.service"

# --- Web Configuration ---
WEB_APP_NAME="moonboard_web"
WEB_TARGET="/home/moonboard_web"
WEB_SERVICE="moonboard_web"
WEB_PORT=3000
# Determine the user for the web service. Prioritize the user running the script via sudo,
# then the primary user (UID 1000), and finally default to 'pi'.
WEB_USER="${SUDO_USER:-$(id -nu 1000 2>/dev/null || echo "pi")}"

# Note: automated-install determines the core user dynamically (usually 'pi'),
# while web-install previously defaulted to 'admin'. This change aligns the user logic.

# Wait for apt/dpkg locks to release (e.g. background updates on first boot)
wait_for_apt_locks() {
    echo "Checking for apt/dpkg locks..."
    while true; do
        if flock -n /var/lib/dpkg/lock-frontend true 2>/dev/null && \
           flock -n /var/lib/dpkg/lock true 2>/dev/null && \
           flock -n /var/lib/apt/lists/lock true 2>/dev/null; then
            break
        fi
        echo "Apt/dpkg database is locked by another process. Waiting 5 seconds..."
        sleep 5
    done
    echo "Apt locks released."
}

# Optimize resource usage on low-memory devices (like Pi Zero/Pi 3 A+ with 512MB RAM)
optimize_low_memory() {
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 900 ]; then
        echo "→ Low memory device detected (${TOTAL_MEM}MB RAM)."
        
        # 1. Increase swap space if dphys-swapfile is available and we are running as root
        if [ "${EUID:-$(id -u)}" -eq 0 ] && [ -f /etc/dphys-swapfile ] && command -v dphys-swapfile &>/dev/null; then
            CURRENT_SWAP=$(grep -E "^CONF_SWAPSIZE=" /etc/dphys-swapfile | cut -d= -f2 || echo "0")
            if [ "$CURRENT_SWAP" -lt 1024 ]; then
                echo "  Increasing swap space to 1024MB..."
                # Replace CONF_SWAPSIZE value or append if not present
                if grep -q "^CONF_SWAPSIZE=" /etc/dphys-swapfile; then
                    sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
                else
                    echo "CONF_SWAPSIZE=1024" >> /etc/dphys-swapfile
                fi
                dphys-swapfile setup
                dphys-swapfile swapon || systemctl restart dphys-swapfile || true
            fi
        fi
        
        # 2. Limit Node memory usage for compilation to prevent OOM
        export NODE_OPTIONS="--max-old-space-size=400"
        echo "  Set NODE_OPTIONS=\"--max-old-space-size=400\""
    fi
}

# --- Shared Logging Helpers ---
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[i]${NC} $1"; }
log_success() { echo -e "${GREEN}[✔]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# --- Shared Bluetooth Helper Functions ---

# Configure BlueZ to use Legacy Advertising (disables ExtendedAdvertising)
configure_bluez_legacy() {
    if [ -f /etc/bluetooth/main.conf ]; then
        log_info "Configuring BlueZ to use Legacy Advertising..."
        if grep -q "^#\?ExtendedAdvertising[[:space:]]*=" /etc/bluetooth/main.conf; then
            sed -i 's/^#\?ExtendedAdvertising[[:space:]]*=.*/ExtendedAdvertising = false/' /etc/bluetooth/main.conf
        else
            sed -i '/^\[General\]/a ExtendedAdvertising = false' /etc/bluetooth/main.conf
        fi
    fi
}

# Ensure bluetooth is not blocked by RF-kill and reset its state
reset_bluetooth_state() {
    if command -v rfkill &> /dev/null; then
        log_info "Checking Bluetooth RF-kill status..."
        if rfkill list bluetooth | grep -q "yes"; then
            log_warn "Bluetooth is blocked by RF-kill. Unblocking..."
            rfkill unblock bluetooth
            sleep 1
        fi
    fi
    if systemctl is-active --quiet bluetooth; then
        log_info "Restarting system bluetooth daemon..."
        systemctl restart bluetooth
        sleep 2

        if command -v bluetoothctl &>/dev/null; then
            log_info "Setting Bluetooth system alias to 'Moonboard A'..."
            for controller in $(bluetoothctl list | awk '{print $2}'); do
                bluetoothctl select "$controller" &>/dev/null || true
                bluetoothctl system-alias "Moonboard A" &>/dev/null || true
            done
        fi
    fi
}