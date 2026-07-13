#!/bin/bash
# Save as /boot/firmware/automated-install.sh

set -euo pipefail

# Log to a place we can see later
LOGFILE="/var/log/moonboard_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Get the actual user created by Imager (usually the first UID 1000)
REAL_USER=$(id -nu 1000 || echo "pi")

# Load shared config
source "$(dirname "$0")/config.sh"
optimize_low_memory

PROJECT_DIR="/boot/firmware/moonboard"

echo "Starting Moonboard Installation..."

# ── Wait for Internet ────────────────────────────────────────────────────────
# (Required because even in automated-install, Wi-Fi takes a few seconds)
echo "Waiting for internet..."
for i in {1..30}; do
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "Internet connected!"
        break
    fi
    sleep 2
done

# ── System packages ──────────────────────────────────────────────────────────
wait_for_apt_locks
apt-get update
apt-get install -y python3 python3-pip dos2unix avahi-daemon \
    python3-dbus python3-gi bluez bluetooth pi-bluetooth bluez-firmware \
    libjpeg-dev libpng-dev zlib1g-dev \
    libopenblas-dev liblapack-dev python3-setuptools python3-pip

# Configure BlueZ to use Legacy Advertising (disables ExtendedAdvertising)
if [ -f /etc/bluetooth/main.conf ]; then
    echo "Configuring BlueZ to use Legacy Advertising..."
    if grep -q "^#\?ExtendedAdvertising[[:space:]]*=" /etc/bluetooth/main.conf; then
        sed -i 's/^#\?ExtendedAdvertising[[:space:]]*=.*/ExtendedAdvertising = false/' /etc/bluetooth/main.conf
    else
        sed -i '/^\[General\]/a ExtendedAdvertising = false' /etc/bluetooth/main.conf
    fi
fi

# ── Copy src ─────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_TARGET"
cp -r "$PROJECT_DIR"/. "$INSTALL_TARGET/"
chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_TARGET"

# ── Python dependencies ──────────────────────────────────────────────────────
# Note: On Bookworm, it's better to use a Virtual Env, 
# but if you must use global, this works:
rm -f /usr/lib/python3*/EXTERNALLY-MANAGED
pip3 install --only-binary=Pillow --ignore-installed -r "$INSTALL_TARGET/install/requirements.txt"

# Enable SPI interface if not already active
sudo raspi-config nonint do_spi 0

# ── Services ─────────────────────────────────────────────────────────────────
# Run the makes as the real user if they need user-level paths
make -C "$INSTALL_TARGET/ble" install
make -C "$INSTALL_TARGET/led" install

# Install Moonboard Web interface and service
echo "Installing Moonboard Web service..."
bash "$INSTALL_TARGET/install/web-install.sh"

# Ensure bluetooth is not blocked by RF-kill and reset its state
if command -v rfkill &> /dev/null; then
    echo "Checking Bluetooth RF-kill status..."
    if rfkill list bluetooth | grep -q "yes"; then
        echo "Bluetooth is blocked by RF-kill. Unblocking..."
        rfkill unblock bluetooth
        sleep 1
    fi
fi
if systemctl is-active --quiet bluetooth; then
    echo "Restarting system bluetooth daemon..."
    systemctl restart bluetooth
    sleep 2
    
    if command -v bluetoothctl &>/dev/null; then
        echo "Setting Bluetooth system alias to 'Moonboard A'..."
        for controller in $(bluetoothctl list | awk '{print $2}'); do
            bluetoothctl select "$controller" || true
            bluetoothctl system-alias "Moonboard A" || true
        done
    fi
fi

# Ensure services are enabled (via Makefiles) and then start them
echo "Starting Moonboard services..."
sudo systemctl daemon-reload
sudo systemctl start "$BLE_SERVICE"
sudo systemctl start "$LED_SERVICE"
sudo systemctl start "$WEB_SERVICE"

# Quick verification check
sudo systemctl is-active "$BLE_SERVICE" "$LED_SERVICE" "$WEB_SERVICE"

echo "Installation complete. This script will not run again."
# No need to edit cmdline.txt or delete itself; 
# Raspberry Pi OS only runs automated-install.sh ONCE.
reboot