.PHONY: deploy install-deps test build-web build-image

# Path to the mounted bootfs (FAT32) partition.
BOOTFS ?= /mnt/bootfs
SD_DRIVE ?=

deploy:
ifneq ($(SD_DRIVE),)
	@echo "→ Mounting $(SD_DRIVE): to $(BOOTFS)"
	@mkdir -p $(BOOTFS)
	@sudo mount -t drvfs $(SD_DRIVE): $(BOOTFS)
endif

	@echo "→ Cleaning old installation..."
	rm -rf $(BOOTFS)/moonboard
	@echo "→ Copying project files to $(BOOTFS)/moonboard/"
	mkdir -p $(BOOTFS)/moonboard
	cp -r src/ble $(BOOTFS)/moonboard/
	cp -r src/led $(BOOTFS)/moonboard/
	cp -r install $(BOOTFS)/moonboard/

	@echo "→ Copying Web UI..."
	mkdir -p $(BOOTFS)/moonboard/web
	@if command -v rsync >/dev/null 2>&1; then \
		rsync -r --exclude='node_modules' --exclude='dist' src/web/ $(BOOTFS)/moonboard/web/; \
	else \
		tar --exclude='node_modules' --exclude='dist' -cf - -C src/web . | tar -xf - -C $(BOOTFS)/moonboard/web; \
	fi

	@echo "→ Make automated-install.sh runnable..."
	chmod +x $(BOOTFS)/moonboard/install/automated-install.sh
	chmod +x $(BOOTFS)/moonboard/install/web-install.sh

	@echo "→ Ensuring cmdline.txt is clean (Removing old init= hooks if present)"
	@if [ -f $(BOOTFS)/cmdline.txt ]; then \
		sed -i.bak 's| init=/boot/firmware/firstrun.sh||g' $(BOOTFS)/cmdline.txt && rm $(BOOTFS)/cmdline.txt.bak; \
	fi

	@echo "→ Injecting trigger into Cloud-Init configuration..."
	python3 install/inject-user-data.py $(BOOTFS)

ifneq ($(SD_DRIVE),)
	@sudo umount $(BOOTFS)
	@echo "→ Done. SD card unmounted — safe to eject."
else
	@echo "→ Done. Files copied to $(BOOTFS). Eject and power on the Pi."
endif

install-deps:
	@echo "→ Setting up Virtual Environment..."
	@if [ -d "venv" ]; then \
		if [ ! -f "./venv/bin/pip" ] || ! ./venv/bin/python3 --version >/dev/null 2>&1; then \
			echo "→ Detected incompatible or broken venv. Recreating..."; \
			rm -rf venv; \
		fi; \
	fi
	test -d venv || python3 -m venv venv
	@echo "→ Installing Python Dev dependencies..."
	./venv/bin/pip install -r install/requirements-dev.txt
	@echo "→ (Future) Installing Node.js dependencies..."
	# cd ./src/web && npm install

build-web:
	@echo "→ Building Web UI..."
	cd ./src/web && npm run build

build-image:
	@echo "→ Running build-image script..."
	sudo bash install/build-image.sh

test:
	@echo "→ Running Python tests..."
	PYTHONPATH=src/ble:src/led:. ./venv/bin/pytest