#!/bin/bash
# Save as /boot/firmware/automated-install.sh

set -euo pipefail

# Log to a place we can see later
LOGFILE="/var/log/moonboard_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Get the actual user created by Imager (usually the first UID 1000)
REAL_USER=$(id -nu 1000 || echo "pi")
PROJECT_DIR="/boot/firmware/moonboard"
INSTALL_TARGET="/opt/moonboard"

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
apt-get update
apt-get install -y python3 python3-pip dos2unix avahi-daemon \
    python3-dbus python3-gi bluez bluetooth \
    libjpeg-dev libpng-dev zlib1g-dev

# ── Copy src ─────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_TARGET"
cp -r "$PROJECT_DIR"/. "$INSTALL_TARGET/"
chown -R "$REAL_USER":"$REAL_USER" "$INSTALL_TARGET"

# ── Python dependencies ──────────────────────────────────────────────────────
# Note: On Bookworm, it's better to use a Virtual Env, 
# but if you must use global, this works:
rm -f /usr/lib/python3*/EXTERNALLY-MANAGED
pip3 install --only-binary=Pillow -r "$INSTALL_TARGET/install/requirements.txt"

# ── Services ─────────────────────────────────────────────────────────────────
# Run the makes as the real user if they need user-level paths
make -C "$INSTALL_TARGET/ble" install
make -C "$INSTALL_TARGET/led" install

echo "Installation complete. This script will not run again."
# No need to edit cmdline.txt or delete itself; 
# Raspberry Pi OS only runs automated-install.sh ONCE.
reboot