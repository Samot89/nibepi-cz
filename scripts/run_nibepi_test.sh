#!/bin/bash
# Test run WITHOUT the heat pump (no RS485 HAT), while another NibePi keeps
# controlling the pump.
#
# Uses its own copy of the config in /opt/nibepi/etc-test; /opt/nibepi/etc is untouched:
#   mqtt.topic = nibetest/modbus/  -> does not remove the other NibePi's HA discovery
#                                     entries and ignores its .../set topics
#   mqtt.discovery = false         -> no new device in Home Assistant
#
# Stop: sudo docker rm -f nibepi-test

set -e

TEST_ETC=/opt/nibepi/etc-test/nibepi
mkdir -p "$TEST_ETC"
cp /opt/nibepi/etc/nibepi/config.json "$TEST_ETC/config.json"
python3 - "$TEST_ETC/config.json" <<'EOF'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["mqtt"]["topic"] = "nibetest/modbus/"
c["mqtt"]["discovery"] = False
json.dump(c, open(p, "w"), indent=2)
print("test config:", c["mqtt"]["topic"], "discovery", c["mqtt"]["discovery"])
EOF

sudo docker rm -f nibepi nibepi-test 2>/dev/null || true
sudo docker run -dit --name nibepi-test \
  -e TZ=Europe/Prague \
  -v /opt/nibepi/data/nibepi-flow:/data \
  -v "$TEST_ETC":/etc/nibepi \
  -v /opt/nibepi/tmp:/tmp \
  -p 1880:1880 \
  nibepi-nodered

echo "Node-RED: http://$(hostname -I | awk '{print $1}'):1880"
echo "Log:      sudo docker logs -f nibepi-test"
