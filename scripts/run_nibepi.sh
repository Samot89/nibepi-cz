#!/bin/bash
# Starts NibePi with the RS485 HAT on /dev/ttyAMA0.
#
# If another NibePi still uses the same MQTT topic, stop it first: on connect this
# version removes legacy Home Assistant discovery entries for its topic (entries
# without unique_id, as published by NibePi 1.x) and publishes its own device.
#
#   --copy-config user@old-host   copy /etc/nibepi/config.json from an old NibePi first
#
# Rebuild after code changes: cd /opt/nibepi/src/nibepi-docker && sudo docker build -t nibepi-nodered .

set -e

if [ "$1" = "--copy-config" ] && [ -n "$2" ]; then
    scp "$2:/etc/nibepi/config.json" /opt/nibepi/etc/nibepi/config.json
fi

sudo docker rm -f nibepi nibepi-test 2>/dev/null || true
# --group-add 20: host group dialout, owner of /dev/ttyAMA0
sudo docker run -dit --name nibepi --restart unless-stopped \
  --device /dev/ttyAMA0:/dev/ttyAMA0 \
  --group-add 20 \
  -e TZ=Europe/Prague \
  -v /opt/nibepi/data/nibepi-flow:/data \
  -v /opt/nibepi/etc/nibepi:/etc/nibepi \
  -v /opt/nibepi/tmp:/tmp \
  -p 1880:1880 \
  nibepi-nodered

echo "Node-RED: http://$(hostname -I | awk '{print $1}'):1880"
echo "Log:      sudo docker logs -f nibepi"
