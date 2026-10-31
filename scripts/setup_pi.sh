#!/bin/bash
# Prepares a Raspberry Pi (Raspberry Pi OS / Debian 12-13, 64-bit) for NibePi in Docker
# with an RS485 HAT on the GPIO UART (/dev/ttyAMA0).
#
# Run as a normal user with sudo rights. Reboot afterwards so the UART change applies.
# The repository is cloned to /opt/nibepi/src/nibepi-cz; config lives in /opt/nibepi/etc.

set -e

REPO=${REPO:-https://github.com/Samot89/nibepi-cz.git}
BASE=/opt/nibepi
SRC=$BASE/src/nibepi-cz

echo "--- Packages"
sudo apt-get update -qq
sudo apt-get install -y -qq git python3 docker.io
# Na novějších systémech je klient Dockeru v samostatném balíku
apt-cache show docker-cli >/dev/null 2>&1 && sudo apt-get install -y -qq docker-cli
sudo usermod -aG docker,dialout "$USER"
sudo systemctl enable --now docker

echo "--- Repository"
sudo mkdir -p $BASE/src $BASE/etc/nibepi $BASE/tmp
sudo chown -R "$USER:$USER" $BASE
[ -d $SRC ] || git clone $REPO $SRC

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
cd $SRC
sudo docker build -t nibepi-nodered .

echo ""
echo "--- Nastavení"
"$SRC/scripts/configure.sh"

echo ""
echo "Hotovo. Zbývá:"
echo "  1. sudo reboot"
echo "  2. $SRC/scripts/run_nibepi.sh"
