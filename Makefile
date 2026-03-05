.PHONY: deploy

# Path to the mounted bootfs (FAT32) partition.
BOOTFS ?= /mnt/bootfs
SD_DRIVE ?=

deploy:
ifneq ($(SD_DRIVE),)
	@echo "→ Mounting $(SD_DRIVE): to $(BOOTFS)"
	@mkdir -p $(BOOTFS)
	@sudo mount -t drvfs $(SD_DRIVE): $(BOOTFS)
endif

	@echo "→ Copying project files to $(BOOTFS)/moonboard/"
	mkdir -p $(BOOTFS)/moonboard
	cp -r src/ble src/led install $(BOOTFS)/moonboard/

	@echo "→ Make automated-install.sh runnable..."
	chmod +x $(BOOTFS)/moonboard/install/automated-install.sh

	@echo "→ Ensuring cmdline.txt is clean (Removing old init= hooks if present)"
	@sed -i 's| init=/boot/firmware/firstrun.sh||g' $(BOOTFS)/cmdline.txt

ifneq ($(SD_DRIVE),)
	@sudo umount $(BOOTFS)
	@echo "→ Done. SD card unmounted — safe to eject."
else
	@echo "→ Done. Files copied to $(BOOTFS). Eject and power on the Pi."
endif