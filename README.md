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

- Use Raspberry Pi Imager to install Raspberry Pi OS Lite (bookworm) onto your sd card
- Deploy the project files to the SD card's boot partition:
  - **On Windows (via WSL):** Run `sudo make deploy SD_DRIVE=D`, where `D` is the drive letter of your SD Card. The script handles mounting and unmounting.
  - **On macOS:** The boot partition typically mounts at `/Volumes/bootfs`. Run `sudo make deploy BOOTFS=/Volumes/bootfs`, then eject the card.
  - **On Linux/Unix:** Mount the SD card's boot partition and run `sudo make deploy BOOTFS=/path/to/bootfs`. Unmount it when done.
- Insert the SD Card into your Raspberry Pi and power it on
- Log in to your Raspberry Pi and run: `sudo /boot/firmware/moonboard/install/automated-install.sh`
- Note that your Raspberry Pi will reboot automatically upon completion.

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

# Versions
- v0.28 merged moonboard mini protocol
- v0.27 merged bt fix test
- v0.23 running in gz setup
