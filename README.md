# moonboard
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)


This project contains software and informations to build a home climbing wall with LED support compatible with the popular moonboard. 
This fork has been done while building my home climbing wall. 

***WIP: Project done. Next step: stabilize the code. ***


![Image of the Wall](doc/front.png)
![LEDs](doc/led.png)

The [moonboard](https://www.moonboard.com/) smartphone app is build to work with the [moonboard led system](https://moonclimbing.com/moonboard-led-system.html) using bluetooth low energy.
In this project we emulate the behaviour of the box using a rasperry pi and addressable LED stripes. 


# Requirements

Besides the tools, time and money (the climbing holds are the most expensive component) you will need:

The hardware used for this project was:
- Raspberry Pi 3 Model A+ with 32GB SD Card - powered over GPIO (Note that the original project used a Rapi W Zero with 8GB SD Card - powered over GPIO)
- 4x LED Strips: 50x WS2811 LED, 5V, 12mm - custom cable length of 23cm (alternatively 3x 4x LED Strips with standard length of 7cm, use mooboard/led/create_nth_led_layout.py to create custom spacing for LED´s)
- Power supply [meanwell mdr-60-5](https://www.meanwell.com/webapp/product/search.aspx?prod=MDR-60) - (~60mA * 50 * 4 = 12A ==> 60 W for 5V)
- Suitable Case (i.e. TEKO)

# Software Installation

- **Choose a compatible OS image:** To use the headless, automated first-boot installation, your OS must natively support **cloud-init** (which is the modern standard replacing legacy `firstrun.sh` setups).
  * **Best Option (Recommended):** Use Raspberry Pi Imager to install **Raspberry Pi OS (Debian Trixie - released November 24, 2025 or newer)**, either Lite or Desktop.
  * **Alternative:** **Ubuntu Server for Raspberry Pi** (which natively supports `cloud-init` out of the box).
  * *Note:* If you use older Debian Bookworm images, `cloud-init` is not pre-installed, and the automated script will be ignored. You will need to install services manually over SSH (see the **Troubleshooting** section).
- Deploy the project files to the SD card's boot partition:
  - **On Windows (via WSL):** Run `sudo make deploy SD_DRIVE=D`, where `D` is the drive letter of your SD Card. The script handles mounting and unmounting.
  - **On macOS:** The boot partition typically mounts at `/Volumes/bootfs`. Run `sudo make deploy BOOTFS=/Volumes/bootfs`, then eject the card.
  - **On Linux/Unix:** Mount the SD card's boot partition and run `sudo make deploy BOOTFS=/path/to/bootfs`. Unmount it when done.
- Insert the SD Card into your Raspberry Pi and power it on.
- The Pi will automatically run the installation script on first boot and reboot upon completion. No manual login or configuration is required.

### Baking a Pre-Baked Image (Linux hosts only)

If you are running Linux (such as Fedora Workstation, Ubuntu, or Debian) on your development computer, you can build a customized, fully pre-baked image file offline. All packages, Python modules, and the compiled Web UI will be pre-installed inside the image on your computer, so the Raspberry Pi does not need internet access when booting up.

1. **Install Host Prerequisites**:
   Ensure you have the required loopback, kpartx, and QEMU user-mode packages installed:
   - **On Fedora Workstation:**
     ```bash
     sudo dnf install -y qemu-user-static kpartx xz unzip wget
     ```
   - **On Ubuntu/Debian:**
     ```bash
     sudo apt-get install -y qemu-user-static binfmt-support kpartx xz-utils unzip wget
     ```
2. **Build the Image**:
   Run the following command from the workspace root:
   ```bash
   make build-image
   ```
   This script will verify the host environment, download the latest Raspberry Pi OS Lite (32-bit Trixie), mount its partitions via loopback, run a `qemu-user-static` chroot to install packages and compile the Web UI, and output a ready-to-flash image at `dist/moonboard_trixie_baked.img`.
3. **Flash the Image**:
   Flash the generated `dist/moonboard_trixie_baked.img` to your SD card using Raspberry Pi Imager or `dd`.


- To test load the Moonboard app on your phone, click on a problem, then click the light icon. 
- This will ask you if you want to connect to a moonboard, click yes

# Installation notes
- I prefer to change the hostname, user and enable ssh. There's are all customisation options in the Raspberry Pi Imager
- The src/led/led_mappings.json needs to be modified to match how you organised your led strip. I split more board into 3 scetions to limit drilling through the cross beams, and I also used every 3rd led. led_mapping_3-Panels.json demonstrates that mapping setup.
- The moonboard services will load whether the led's are connected or not. You can look for the logs files to see if they are working.

# Moonboard Build Instructions

- [How to Build a Home Climbing Wall](doc/BUILD-WALL.md)
- [How to Build the LED System](doc/BUILD-LEDSYSTEM.md)
- [Software Description](doc/OVERVIEW-SOFTWARE.md)

## Example boards
Free standing foldaway version of moonboard. Moonboard with 150mm kicker and total height of 2900mm, some alteration for 2016 hold setup needs to be done since one hold cannot fit in shortened top panel.

![MB folded away](doc/MB-front-folded.jpg)
![MB unfolded ready to train](doc/MB-front-unfolded.jpg)



## Troubleshooting
- In case of bluetooth connection problems: make sure to have paired your phone with the raspi once.

## Tested setups
- Raspi W Zero with iPhone 5, 8, X, 11 (iOS >= 14)

# Development

To set up the development environment, run tests, or work on the web application locally:

### 1. Setup Local Dependencies
Set up the Python virtual environment and install development dependencies:
```bash
make install-deps
```

### 2. Running Unit Tests
You can run the Python unit tests locally using:
```bash
make test
```

### 3. Developing and Building the Web UI
The React web application source is located in `src/web/`.
* To run the local development server for the web app:
  ```bash
  cd src/web
  npm install
  npm run dev
  ```
* To compile a production build of the Web UI (which gets copied during deployment):
  ```bash
  make build-web
  ```

# Versions
- v0.28 merged moonboard mini protocol
- v0.27 merged bt fix test
- v0.23 running in gz setup

