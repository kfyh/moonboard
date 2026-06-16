# Software Overview & Installation

This document describes the software services running on the Moonboard controller (Raspberry Pi) and how to manage them.

## Software Installation Instructions

1. **Flash OS**: Run **Raspberry Pi Imager** to write a fresh **Raspberry Pi OS Lite (Bookworm)** image to your SD card. We recommend customizing the hostname, user credentials, and enabling SSH in the Imager settings.

2. **Identify SD Card Drive**:
   - **Windows**: Open File Explorer, note the drive letter assigned to your SD card (e.g., `E:`)
   - **Mac**: Open Disk Utility, select your SD card, and note the identifier (e.g., `disk2s1`)
   - **Linux**: Run `lsblk` in terminal to identify your SD card (typically `/dev/sdX1` or `/dev/mmcblk0p1`)

3. **Deploy Code**:
   - Open a terminal/command prompt in this project directory
   - Run the appropriate single-line deploy command for your OS:

   **Windows (PowerShell)**:

