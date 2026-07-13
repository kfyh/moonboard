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