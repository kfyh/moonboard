#!/bin/bash
# install/build-image.sh

set -euo pipefail

# Allow mocking for testability
MOCK_EUID=${MOCK_EUID:-$EUID}
MOCK_LOOP_CONTROL=${MOCK_LOOP_CONTROL:-/dev/loop-control}

# 1. Check OS
if [ "$(uname -s)" != "Linux" ]; then
    echo "Error: This script must be run on Linux." >&2
    exit 1
fi

# 2. Check root/sudo permissions
if [ "$MOCK_EUID" -ne 0 ] && [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with root privileges (sudo)." >&2
    exit 1
fi

# 3. Check loop-control device
if [ "$MOCK_LOOP_CONTROL" = "/dev/loop-control" ]; then
    if [ ! -c "$MOCK_LOOP_CONTROL" ]; then
        echo "Error: /dev/loop-control device not found." >&2
        exit 1
    fi
else
    if [ ! -f "$MOCK_LOOP_CONTROL" ]; then
        echo "Error: /dev/loop-control device not found." >&2
        exit 1
    fi
fi

# 4. Check required tools
REQUIRED_TOOLS=("mount" "unzip" "wget" "xz" "curl" "parted")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool '$tool' is not installed." >&2
        exit 1
    fi
done

# kpartx or losetup
if ! command -v kpartx >/dev/null 2>&1 && ! command -v losetup >/dev/null 2>&1; then
    echo "Error: Neither 'kpartx' nor 'losetup' was found. One of them is required." >&2
    exit 1
fi

# qemu-arm-static or qemu-aarch64-static
if ! command -v qemu-arm-static >/dev/null 2>&1 && ! command -v qemu-aarch64-static >/dev/null 2>&1; then
    echo "Error: Neither 'qemu-arm-static' nor 'qemu-aarch64-static' was found. QEMU user static binary is required." >&2
    exit 1
fi

# If we only wanted to check the environment, exit now
if [ "${1:-}" = "--check-only" ]; then
    echo "Environment check passed."
    exit 0
fi

# --- Core Logic ---

# Determine project root (allow override via environment variable)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Ensure directories exist
mkdir -p cache build dist

CACHE_IMG="cache/raspios_lite_latest.img"
CACHE_XZ="cache/raspios_lite_latest.img.xz"

WORKING_IMG="build/moonboard_trixie_baked.img"
BAKED_IMG="dist/moonboard_trixie_baked.img"
MNT_DIR="build/mnt"
LOOP_DEV=""

# A. Download and decompress cached image
if [ ! -f "$CACHE_IMG" ]; then
    # Dynamically fetch the latest 32-bit Trixie Lite URL from the official imager database
    echo "→ Fetching latest image URL..."
    DOWNLOAD_URL=$(curl -s https://downloads.raspberrypi.com/os_list_imagingutility_v4.json | grep -o -E '"url": *"[^"]+"' | grep -E "raspios_lite_armhf.*trixie" | head -n 1 | cut -d '"' -f 4)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo "Error: Failed to fetch the latest Raspberry Pi OS Lite URL." >&2
        exit 1
    fi
    echo "→ Latest image URL is: $DOWNLOAD_URL"

    if [ ! -f "$CACHE_XZ" ]; then
        echo "→ Downloading latest Raspberry Pi OS Lite image..."
        wget -O "$CACHE_XZ" "$DOWNLOAD_URL"
    fi
    echo "→ Decompressing Raspberry Pi OS Lite image..."
    xz -d -k "$CACHE_XZ"
    # Ensure the decompressed image matches our cache target
    # If the decompressed image had a different name (e.g. from the url redirect), we rename/move it.
    DECOMPRESSED_IMG=$(ls cache/*.img 2>/dev/null | grep -v "raspios_lite_latest.img" | head -n 1 || echo "")
    if [ -n "$DECOMPRESSED_IMG" ]; then
        mv "$DECOMPRESSED_IMG" "$CACHE_IMG"
    fi
fi

# Ensure clean working image
echo "→ Creating a copy of the image for baking..."
cp "$CACHE_IMG" "$WORKING_IMG"

echo "→ Expanding working image size by 2GB..."
truncate -s +2G "$WORKING_IMG"
parted -s "$WORKING_IMG" resizepart 2 100%

cleanup() {
    echo "→ Cleaning up mounts and loop devices..."
    # 1. Unmount bind mounts in reverse order
    for mount_point in dev/pts dev sys proc run; do
        if mountpoint -q "$MNT_DIR/$mount_point" 2>/dev/null; then
            umount -f "$MNT_DIR/$mount_point" || true
        fi
    done

    # 2. Restore resolv.conf in chroot
    if [ -f "$MNT_DIR/etc/resolv.conf.bak" ]; then
        mv "$MNT_DIR/etc/resolv.conf.bak" "$MNT_DIR/etc/resolv.conf" || true
    fi

    # 3. Unmount rootfs and bootfs
    BOOT_MNT="$MNT_DIR/boot/firmware"
    if [ ! -d "$BOOT_MNT" ]; then
        BOOT_MNT="$MNT_DIR/boot"
    fi
    if mountpoint -q "$BOOT_MNT" 2>/dev/null; then
        umount -f "$BOOT_MNT" || true
    fi
    if mountpoint -q "$MNT_DIR" 2>/dev/null; then
        umount -f "$MNT_DIR" || true
    fi

    # 4. Detach loop device
    if [ -n "${LOOP_DEV}" ]; then
        echo "→ Detaching loop device $LOOP_DEV..."
        losetup -d "$LOOP_DEV" || true
    fi
}
trap cleanup EXIT

# B. Mount and Chroot Emulation
echo "→ Attaching image to loop device..."
LOOP_DEV=$(losetup -fP --show "$WORKING_IMG")
echo "Attached to loop device: $LOOP_DEV"

sleep 2

BOOT_PART="${LOOP_DEV}p1"
ROOT_PART="${LOOP_DEV}p2"

LOOP_BASE=$(basename "$LOOP_DEV")
if { [ ! -b "$BOOT_PART" ] && [ ! -f "$BOOT_PART" ]; } || { [ ! -b "$ROOT_PART" ] && [ ! -f "$ROOT_PART" ]; }; then
    # Fallback to mapper devices
    if [ -b "/dev/mapper/${LOOP_BASE}p1" ] || [ -f "/dev/mapper/${LOOP_BASE}p1" ]; then
        BOOT_PART="/dev/mapper/${LOOP_BASE}p1"
        ROOT_PART="/dev/mapper/${LOOP_BASE}p2"
    else
        echo "Partitions not found directly. Trying kpartx..."
        kpartx -av "$LOOP_DEV" || true
        sleep 1
        if [ -b "/dev/mapper/${LOOP_BASE}p1" ] || [ -f "/dev/mapper/${LOOP_BASE}p1" ]; then
            BOOT_PART="/dev/mapper/${LOOP_BASE}p1"
            ROOT_PART="/dev/mapper/${LOOP_BASE}p2"
        fi
    fi
fi

if { [ ! -b "$BOOT_PART" ] && [ ! -f "$BOOT_PART" ]; } || { [ ! -b "$ROOT_PART" ] && [ ! -f "$ROOT_PART" ]; }; then
    echo "Error: Partitions $BOOT_PART or $ROOT_PART do not exist or could not be mapped." >&2
    exit 1
fi

echo "→ Checking and resizing root filesystem on $ROOT_PART..."
e2fsck -f -y "$ROOT_PART" || true
resize2fs "$ROOT_PART"

echo "→ Mounting root partition $ROOT_PART..."
mkdir -p "$MNT_DIR"
mount "$ROOT_PART" "$MNT_DIR"

BOOT_MNT="$MNT_DIR/boot/firmware"
if [ ! -d "$BOOT_MNT" ]; then
    BOOT_MNT="$MNT_DIR/boot"
fi
mkdir -p "$BOOT_MNT"

echo "→ Mounting boot partition $BOOT_PART to $BOOT_MNT..."
mount "$BOOT_PART" "$BOOT_MNT"

echo "→ Setting up QEMU static emulator..."
QEMU_BIN=$(command -v qemu-arm-static || command -v qemu-aarch64-static)
mkdir -p "$MNT_DIR/usr/bin"
cp "$QEMU_BIN" "$MNT_DIR/usr/bin/qemu-arm-static"

echo "→ Bind mounting system directories..."
mkdir -p "$MNT_DIR/dev/pts" "$MNT_DIR/sys" "$MNT_DIR/proc" "$MNT_DIR/run"
mount --bind /dev "$MNT_DIR/dev"
mount --bind /dev/pts "$MNT_DIR/dev/pts"
mount --bind /sys "$MNT_DIR/sys"
mount --bind /proc "$MNT_DIR/proc"
mount --bind /run "$MNT_DIR/run"

echo "→ Configuring DNS in chroot..."
mkdir -p "$MNT_DIR/etc"
if [ -f "$MNT_DIR/etc/resolv.conf" ]; then
    mv "$MNT_DIR/etc/resolv.conf" "$MNT_DIR/etc/resolv.conf.bak"
fi
cp -L /etc/resolv.conf "$MNT_DIR/etc/resolv.conf"

# C. Workspace Code Copying
echo "→ Cleaning up target folders inside the chroot..."
rm -rf "$MNT_DIR/opt/moonboard"
rm -rf "$BOOT_MNT/moonboard"

mkdir -p "$MNT_DIR/opt/moonboard"
mkdir -p "$BOOT_MNT/moonboard"

echo "→ Copying source code..."
tar --exclude='node_modules' --exclude='dist' --exclude='venv' --exclude='.git' --exclude='build' --exclude='cache' -cf - -C "$PROJECT_ROOT" . | tar --no-same-owner -xf - -C "$MNT_DIR/opt/moonboard/"
tar --exclude='node_modules' --exclude='dist' --exclude='venv' --exclude='.git' --exclude='build' --exclude='cache' -cf - -C "$PROJECT_ROOT" . | tar --no-same-owner -xf - -C "$BOOT_MNT/moonboard/"

# D. Offline Baking (Chroot execution)
mkdir -p "$MNT_DIR/tmp"
CHROOT_SCRIPT="$MNT_DIR/tmp/chroot-install.sh"
cat << 'EOF' > "$CHROOT_SCRIPT"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "========================================="
echo "  Executing custom baking inside chroot  "
echo "========================================="

# Get system user (UID 1000) or default to 'pi'
REAL_USER=$(id -nu 1000 2>/dev/null || echo "pi")
echo "Baking packages for user: $REAL_USER"

# Update package repository
apt-get update

# Install required system packages
apt-get install -y python3 python3-pip dos2unix avahi-daemon \
    python3-dbus python3-gi bluez bluetooth \
    libjpeg-dev libpng-dev zlib1g-dev \
    libopenblas-dev liblapack-dev python3-setuptools python3-pip

# Remove EXTERNALLY-MANAGED python constraint to allow global installs
rm -f /usr/lib/python3*/EXTERNALLY-MANAGED || true

# Install Python requirements
if [ -f /opt/moonboard/install/requirements.txt ]; then
    pip3 install --only-binary=Pillow --ignore-installed -r /opt/moonboard/install/requirements.txt
fi

# Install Node.js v20+
if command -v node &>/dev/null && [ $(node -v | cut -d. -f1 | tr -d 'v') -ge 20 ]; then
    echo "Node.js $(node -v) is already installed."
else
    CANDIDATE=$(apt-cache policy nodejs | grep Candidate | awk '{print $2}' || echo "")
    MAJOR_VER=$(echo "$CANDIDATE" | cut -d. -f1 || echo "")
    if [[ "$MAJOR_VER" =~ ^[0-9]+$ ]] && [[ "$MAJOR_VER" -ge 20 ]]; then
        echo "Installing Node.js v$MAJOR_VER via apt..."
        apt-get install -y nodejs npm
    else
        echo "System node version insufficient. Installing Node.js manually..."
        apt-get install -y curl xz-utils
        NODE_DIST="v20.11.1"
        curl -fsSL "https://nodejs.org/dist/${NODE_DIST}/node-${NODE_DIST}-linux-armv7l.tar.xz" -o /tmp/node-install.tar.xz
        tar -xJf /tmp/node-install.tar.xz --strip-components=1 -C /usr/local
        rm -f /tmp/node-install.tar.xz
        ln -sf /usr/local/bin/node /usr/bin/node
        ln -sf /usr/local/bin/npm /usr/bin/npm
    fi
fi

# Setup Web Application target
WEB_TARGET="/home/moonboard_web"
rm -rf "$WEB_TARGET/node_modules" "$WEB_TARGET/dist"
mkdir -p "$WEB_TARGET"

# Copy Web UI files
cp -r /opt/moonboard/src/web/. "$WEB_TARGET/"

# Copy led_mapping.json if it exists
if [ -f /opt/moonboard/src/led/led_mapping.json ]; then
    cp /opt/moonboard/src/led/led_mapping.json "$WEB_TARGET/led_mapping.json"
fi

chown -R "$REAL_USER":"$REAL_USER" "$WEB_TARGET"

cd "$WEB_TARGET"
echo "Installing Web dependencies..."
sudo -u "$REAL_USER" HOME="/home/$REAL_USER" npm install

echo "Compiling Web application..."
sudo -u "$REAL_USER" HOME="/home/$REAL_USER" npm run build

# Install services
echo "Installing BLE and LED services..."
make -C /opt/moonboard/src/ble install
make -C /opt/moonboard/src/led install

echo "Installing Web service..."
cp /opt/moonboard/src/web/service/moonboard_web.service /lib/systemd/system/moonboard_web.service
chmod 644 /lib/systemd/system/moonboard_web.service
sed -i "s/^User=.*/User=$REAL_USER/" /lib/systemd/system/moonboard_web.service
systemctl enable moonboard_web.service

# Enable SPI interface in boot config
CONFIG_TXT=""
if [ -f /boot/firmware/config.txt ]; then
    CONFIG_TXT="/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    CONFIG_TXT="/boot/config.txt"
fi

if [ -n "$CONFIG_TXT" ]; then
    echo "Enabling SPI in $CONFIG_TXT..."
    if grep -q "^#dtparam=spi=on" "$CONFIG_TXT"; then
        sed -i 's/^#dtparam=spi=on/dtparam=spi=on/' "$CONFIG_TXT"
    elif ! grep -q "^dtparam=spi=on" "$CONFIG_TXT"; then
        echo "dtparam=spi=on" >> "$CONFIG_TXT"
    fi
fi

echo "Chroot baking completed successfully!"
EOF

chmod +x "$CHROOT_SCRIPT"

echo "→ Running the installation script inside chroot..."
chroot "$MNT_DIR" /bin/bash /tmp/chroot-install.sh

# E. Clean up Guest files and unmount
echo "→ Cleaning up guest QEMU emulator and chroot script..."
rm -f "$CHROOT_SCRIPT"
rm -f "$MNT_DIR/usr/bin/qemu-arm-static"

# Restore resolv.conf in guest
if [ -f "$MNT_DIR/etc/resolv.conf.bak" ]; then
    mv "$MNT_DIR/etc/resolv.conf.bak" "$MNT_DIR/etc/resolv.conf"
fi

cleanup

# Disable trap on success
trap - EXIT

echo "→ Moving baked image to final destination..."
mv "$WORKING_IMG" "$BAKED_IMG"

echo "→ Success! Customized offline image is ready at $BAKED_IMG"
