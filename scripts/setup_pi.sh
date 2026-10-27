#!/bin/bash
# Prepares a Raspberry Pi (Raspberry Pi OS / Debian 12-13, 64-bit) for NibePi in Docker
# with an RS485 HAT on the GPIO UART (/dev/ttyAMA0).
#
# Run as a normal user with sudo rights. Reboot afterwards so the UART change applies.
# Repos are cloned to /opt/nibepi/src (code) and /opt/nibepi/data (flows).

set -e

GH=${GH:-https://github.com/Samot89}
BASE=/opt/nibepi

echo "--- Packages"
sudo apt-get update -qq
sudo apt-get install -y -qq git docker.io docker-cli
sudo usermod -aG docker,dialout "$USER"
sudo systemctl enable --now docker

echo "--- Repositories"
sudo mkdir -p $BASE/src $BASE/data $BASE/etc/nibepi $BASE/tmp
sudo chown -R "$USER:$USER" $BASE
cd $BASE/src
[ -d nibepi-docker ] || git clone $GH/nibepi-docker.git
cd nibepi-docker
[ -d nibepi ] || git clone $GH/nibepi-backend.git nibepi
[ -d node-red-contrib-nibepi ] || git clone $GH/node-red-contrib-nibepi.git
cd $BASE/data
[ -d nibepi-flow ] || git clone $GH/nibepi-flow.git

echo "--- UART for the RS485 HAT"
BOOT=/boot/firmware
[ -f $BOOT/config.txt ] || BOOT=/boot
sudo cp -n $BOOT/config.txt $BOOT/config.txt.bak
sudo cp -n $BOOT/cmdline.txt $BOOT/cmdline.txt.bak
# No serial console on the UART the HAT uses
sudo sed -i 's/console=serial0,[0-9]* //' $BOOT/cmdline.txt
# Full PL011 UART (ttyAMA0) on GPIO 14/15, Bluetooth off.
# config.txt may not end with a newline, so add one first.
if ! grep -q '^enable_uart=1' $BOOT/config.txt; then
    sudo sh -c "echo >> $BOOT/config.txt; printf 'enable_uart=1\ndtoverlay=disable-bt\n' >> $BOOT/config.txt"
fi

echo "--- Docker image (takes a while on a Pi Zero 2 W)"
cd $BASE/src/nibepi-docker
sudo docker build -t nibepi-nodered .

echo ""
echo "Done. Next:"
echo "  1. Copy examples/config.example.json to $BASE/etc/nibepi/config.json and fill it in"
echo "  2. sudo reboot"
echo "  3. scripts/run_nibepi.sh"
