# --- Image Build ---
# Variables for image building. IMG_DIR can be overridden from command line.
IMG_DIR ?= build
RASPI_OS_URL := https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-11-raspios-bookworm-armhf-lite.img.xz
RASPI_OS_XZ := $(IMG_DIR)/$(notdir $(RASPI_OS_URL))
RASPI_OS_IMG := $(IMG_DIR)/$(basename $(notdir $(RASPI_OS_URL)))
MNT_POINT := /mnt/raspi_img
PROJECT_DIR_ON_IMG := /home/admin/moonboard

# Main build target
build-image: setup-qemu download-image resize-image mount-image copy-files install-software unmount-and-resize
	@echo "--- Image build complete: $(RASPI_OS_IMG) is ready to be flashed. ---"

# Download and decompress the image
download-image: $(RASPI_OS_IMG)

$(RASPI_OS_IMG): $(RASPI_OS_XZ)
	@echo "--- Decompressing Raspberry Pi OS Image ---"
	xz -d -k -T 0 $<

$(RASPI_OS_XZ):
	@echo "--- Downloading Raspberry Pi OS Image ---"
	mkdir -p $(IMG_DIR)
	wget -O $@ $(RASPI_OS_URL)

# Resize the image and partition
resize-image:
	@echo "--- Expanding Image Size ---"
	truncate -s +2G $(RASPI_OS_IMG)
	sudo parted -s $(RASPI_OS_IMG) resizepart 2 100%

# Set up QEMU for ARM emulation
setup-qemu:
	@echo "--- Setting up QEMU binfmt ---"
	sudo sh -c 'echo ":arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:" > /proc/sys/fs/binfmt_misc/register' || true

# Mount the image and set up the chroot environment
mount-image:
	@echo "--- Mounting Image ---"
	LOOP_DEV=$$(sudo losetup -f --show $(RASPI_OS_IMG)); \
	echo $$LOOP_DEV > $(IMG_DIR)/loop_dev; \
	sudo kpartx -a $$LOOP_DEV; \
	sudo mkdir -p $(MNT_POINT); \
	sudo mount /dev/mapper/$$(basename $$LOOP_DEV)p2 $(MNT_POINT); \
	sudo mount /dev/mapper/$$(basename $$LOOP_DEV)p1 $(MNT_POINT)/boot; \
	sudo mount --bind /dev $(MNT_POINT)/dev; \
	sudo mount --bind /sys $(MNT_POINT)/sys; \
	sudo mount --bind /proc $(MNT_POINT)/proc; \
	sudo mount --bind /dev/pts $(MNT_POINT)/dev/pts;

# Copy project files to the image
copy-files:
	@echo "--- Copying QEMU and project files ---"
	sudo cp /usr/bin/qemu-arm-static $(MNT_POINT)/usr/bin/
	sudo mkdir -p $(MNT_POINT)$(PROJECT_DIR_ON_IMG)
	sudo rsync -a . $(MNT_POINT)$(PROJECT_DIR_ON_IMG) --exclude $(IMG_DIR) --exclude '.git*'
	@echo "--- Enabling SSH ---"
	sudo touch $(MNT_POINT)/boot/ssh

# Install software
install-software: setup-user-and-host install-dependencies install-services

# Setup user and hostname
setup-user-and-host:
	@echo "--- Setting up user and hostname ---"
	sudo chroot $(MNT_POINT) /bin/bash -c "\
		set -e; \
		if id -u pi > /dev/null 2>&1; then userdel -r pi; fi; \
		if ! id -u admin > /dev/null 2>&1; then useradd -m -s /bin/bash admin; fi; \
		echo 'admin:password' | chpasswd; \
		echo 'admin ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/010_admin-nopasswd; \
		echo 'moonboard-pi' > /etc/hostname; \
		sed -i 's/raspberrypi/moonboard-pi/g' /etc/hosts; \
		chown -R admin:admin /home/admin; \
	"

# Install python dependencies
install-dependencies:
	@echo "--- Installing dependencies ---"
	sudo chroot $(MNT_POINT) /bin/bash -c "\
		set -e; \
		export DEBIAN_FRONTEND=noninteractive; \
		apt-get update; \
		apt-get remove -y userconf-pi || true; \
		apt-get install -y python3-pip git avahi-daemon python3-dbus python3-gi; \
		systemctl enable avahi-daemon; \
		rm -f /usr/lib/python*/EXTERNALLY-MANAGED; \
		cd $(PROJECT_DIR_ON_IMG); \
		pip3 install -r install/requirements.txt; \
	"

# Install services
install-services:
	@echo "--- Installing services ---"
	sudo chroot $(MNT_POINT) /bin/bash -c "\
		set -e; \
		cd $(PROJECT_DIR_ON_IMG); \
		make -C ble install; \
		make -C led install; \
	"

# Unmount the image and resize the filesystem
unmount-and-resize:
	@echo "--- Unmounting image and resizing filesystem ---"
	sudo umount -lR $(MNT_POINT) || true; \
	LOOP_DEV=$$(cat $(IMG_DIR)/loop_dev); \
	sudo e2fsck -f -p /dev/mapper/$$(basename $$LOOP_DEV)p2 || true; \
	sudo resize2fs /dev/mapper/$$(basename $$LOOP_DEV)p2; \
	sudo kpartx -d $$LOOP_DEV; \
	sudo losetup -d $$LOOP_DEV; \
	rm $(IMG_DIR)/loop_dev
