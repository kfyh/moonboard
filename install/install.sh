#!/bin/bash

echo "Enable SPI"
sudo sed -i 's/\#dtparam=spi=on/dtparam=spi=on/g' /boot/config.txt

echo "Disable Audio"
sudo sed -i 's/\dtparam=audio=on/#dtparam=audio=on/g' /boot/config.txt
echo blacklist snd_bcm2835 | sudo tee /etc/modprobe.d/raspi-blacklist.conf 


# Install dependencies
echo "Install dependencies"
sudo apt-get update
sudo apt-get upgrade

echo "Install + build led drivers"
sudo apt-get -y install git vim python3-pip python3-rpi.gpio gcc make build-essential
sudo apt-get -y install libatlas-base-dev 
sudo apt-get -y install python-dev swig scons # for building WS2811 drivers

# Installing python dependencies
echo "Installing python dependencies"
pip3 install -r install/requirements.txt
sudo pip3 install -r install/requirements.txt 

echo "Install services" # FIXME
cd /home/pi/moonboard/ble
make install
cd ..

cd /home/pi/moonboard/led
make install 
cd ..

echo "Restarting in 5 seconds to finalize changes. CTRL+C to cancel."
sleep 1 > /dev/null
printf "."
sleep 1 > /dev/null
printf "."
sleep 1 > /dev/null
printf "."
sleep 1 > /dev/null
printf "."
sleep 1 > /dev/null
printf " Restarting"
sudo shutdown -r now
