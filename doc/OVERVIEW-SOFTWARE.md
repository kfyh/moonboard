# Software Overview & Installation

This document describes the software services running on the Moonboard controller (Raspberry Pi) and how to manage them.

## Software Installation Instructions

1. **Flash OS**: Run **Raspberry Pi Imager** to write a fresh **Raspberry Pi OS Lite (Bookworm)** image to your SD card. We recommend customizing the hostname, user credentials, and enabling SSH in the Imager settings.
2. **Deploy Code**: Refer to the deployment instructions in the root [README.md](file:///Users/localkevin/workspace/moonboard/README.md#software-installation) to copy the project files to the SD card and configure cloud-init by running the `make deploy` command.
3. **Power On**: Insert the SD Card into your Raspberry Pi and power it on. The Pi will automatically execute the installation via cloud-init on first boot and reboot when done. No manual SSH login or CLI configuration is required.


---

## Software Description

The system consists of three systemd services:

1. **Bluetooth BLE Service (`com.moonboard.service`)**
   * Emulates the UART Bluetooth Low Energy profile of the original Moonboard LED box.
   * When a climbing problem is selected and sent from the smartphone app, the BLE service parses the protocol payload and emits a signal containing the holds on the system DBus.
2. **LED Driver Service (`moonboard_led.service`)**
   * Listens on the system DBus for new problem signals.
   * Converts the grid coordinates to physical LED indexes using the layout specified in [led_mapping.json](file:///Users/localkevin/workspace/moonboard/src/led/led_mapping.json) and drives the WS2811 strips.
3. **Web Interface Service (`moonboard_web.service`)**
   * Hosts a local Node.js API and React static UI on port `3000`.
   * Allows control of the board and holds directly from a web browser.

---

## Managing Services

Use `systemctl` to manage the services on the Raspberry Pi:

### Status Checks
```bash
sudo systemctl status com.moonboard.service
sudo systemctl status moonboard_led.service
sudo systemctl status moonboard_web.service
```

### Stopping / Restarting Services
For debugging or updating configurations:
```bash
# Restart the LED service
sudo systemctl restart moonboard_led.service

# Stop all services
sudo systemctl stop com.moonboard.service moonboard_led.service moonboard_web.service
```

### Viewing Logs
* **BLE Service Logs**:
  ```bash
  journalctl -u com.moonboard.service -f
  # Or view raw output files:
  tail -f /var/log/moonboard_ble_stdout.log
  tail -f /var/log/moonboard_ble_stderr.log
  ```
* **LED Service Logs**:
  ```bash
  journalctl -u moonboard_led.service -f
  # Or view raw output files:
  tail -f /var/log/moonboard_led_stdout.log
  tail -f /var/log/moonboard_led_stderr.log
  ```
* **Web UI Service Logs**:
  ```bash
  journalctl -u moonboard_web.service -f
  ```
