#!/bin/bash
# Pi Zero 2 W: Bluetooth off, WiFi without power save, fixed MAC, full transmit power.
# Power save on the brcmfmac chip is a known cause of WiFi drop-outs. Safe to run again.
set -e
IW=/usr/sbin/iw

echo "--- Bluetooth off (dtoverlay=disable-bt in config.txt disables the chip; this stops the service)"
sudo systemctl disable --now bluetooth.service 2>/dev/null || true
sudo systemctl mask bluetooth.service

echo "--- WiFi power save off and fixed MAC address, for every future connection"
sudo tee /etc/NetworkManager/conf.d/90-nibepi-wifi.conf >/dev/null <<'EOF'
[connection]
# 2 = disable
wifi.powersave=2
wifi.cloned-mac-address=permanent

[device]
wifi.scan-rand-mac-address=no
EOF
sudo nmcli general reload conf

echo "--- Full transmit power and power save off again whenever wlan0 comes up (iw settings do not survive a reconnect)"
sudo tee /etc/NetworkManager/dispatcher.d/90-nibepi-wifi >/dev/null <<'EOF'
#!/bin/sh
[ "$1" = "wlan0" ] && [ "$2" = "up" ] || exit 0
/usr/sbin/iw dev wlan0 set power_save off
/usr/sbin/iw dev wlan0 set txpower fixed 3100 2>/dev/null || /usr/sbin/iw dev wlan0 set txpower auto
EOF
sudo chmod 755 /etc/NetworkManager/dispatcher.d/90-nibepi-wifi

echo "--- Now, without reconnecting"
sudo $IW dev wlan0 set power_save off
# Highest setting the driver accepts; the CZ regulatory limit (20 dBm at 2.4 GHz) still applies
sudo $IW dev wlan0 set txpower fixed 3100 2>/dev/null || sudo $IW dev wlan0 set txpower auto

$IW dev wlan0 get power_save
$IW dev wlan0 info | grep txpower
systemctl is-enabled bluetooth.service || true
