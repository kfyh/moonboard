# --- Image Build ---
# Variables for image building. IMG_DIR can be overridden from command line.
IMG_DIR ?= build
CACHE_DIR ?= cache
RASPI_OS_URL := https://downloads.raspberrypi.com/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-11-raspios-bookworm-armhf-lite.img.xz
RASPI_OS_XZ := $(CACHE_DIR)/$(notdir $(RASPI_OS_URL))
RASPI_OS_IMG := $(IMG_DIR)/$(basename $(notdir $(RASPI_OS_URL)))
MNT_POINT := /mnt/raspi_img
PROJECT_DIR_ON_IMG := /home/admin/moonboard

.PHONY: clean
clean:
	@echo "--- Cleaning up build artifacts ---"
	sudo rm -rf $(IMG_DIR)

.PHONY: clean-pip-cache
clean-pip-cache:
	@echo "--- Cleaning pip cache ---"
	rm -rf $(CACHE_DIR)/pip_cache

# Main build target
build-image: setup-qemu download-image resize-image mount-image copy-files install-software unmount-and-resize
	@echo "--- Image build complete: $(RASPI_OS_IMG) is ready to be flashed. ---"

# Download and decompress the image
download-image: $(RASPI_OS_IMG)

$(RASPI_OS_IMG): $(RASPI_OS_XZ)
	@echo "--- Decompressing Raspberry Pi OS Image from $(CACHE_DIR) to $(IMG_DIR) ---"
	mkdir -p $(IMG_DIR)
	xz -d -c -T 0 $< > $@

$(RASPI_OS_XZ):
	@echo "--- Downloading Raspberry Pi OS Image to $(CACHE_DIR) ---"
	mkdir -p $(CACHE_DIR)
	wget -O $@ $(RASPI_OS_URL)

# Resize the image and partition
resize-image:
	@echo "--- Expanding Image Size ---"
	# Expand the image to a fixed size of 4GB to avoid it growing on every build.
	truncate -s 4G $(RASPI_OS_IMG)
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
	sudo mount --bind /dev/pts $(MNT_POINT)/dev/pts; \
	@echo "--- Setting up pip cache ---"; \
	mkdir -p $(CACHE_DIR)/pip_cache; \
	chmod 777 $(CACHE_DIR)/pip_cache; \
	sudo mkdir -p $(MNT_POINT)/var/cache/pip-host; \
	sudo mount --bind $(CACHE_DIR)/pip_cache $(MNT_POINT)/var/cache/pip-host;

# Copy project files to the image
copy-files:
	@echo "--- Copying QEMU and project files ---"
	sudo cp /usr/bin/qemu-arm-static $(MNT_POINT)/usr/bin/
	sudo mkdir -p $(MNT_POINT)$(PROJECT_DIR_ON_IMG)
	sudo rsync -a src/ $(MNT_POINT)$(PROJECT_DIR_ON_IMG)
	@echo "--- Copying startup scripts ---"
	sudo mkdir -p $(MNT_POINT)/usr/local/bin
	sudo cp src/install/run-led-service.sh $(MNT_POINT)/usr/local/bin/
	sudo cp src/install/run-ble-service.sh $(MNT_POINT)/usr/local/bin/
	sudo chmod +x $(MNT_POINT)/usr/local/bin/run-led-service.sh
	sudo chmod +x $(MNT_POINT)/usr/local/bin/run-ble-service.sh
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
		apt-get install -y dos2unix python3-pip git avahi-daemon python3-dbus python3-gi; \
		systemctl enable avahi-daemon; \
		rm -f /usr/lib/python*/EXTERNALLY-MANAGED; \
		cd $(PROJECT_DIR_ON_IMG); \
		pip3 install --cache-dir /var/cache/pip-host -r install/requirements.txt; \
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
