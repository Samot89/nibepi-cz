#!/bin/bash
# Installs a daily check (03:30) that restarts NibePi only when swap use is high.
# See nibepi_restart.sh for what it does. Remove with:
#   sudo systemctl disable --now nibepi-restart.timer
#   sudo rm /etc/systemd/system/nibepi-restart.{service,timer}
#
#   SWAP_LIMIT_PCT=85 ./scripts/install_restart_timer.sh   (limit in %, default 85)
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
LIMIT=${SWAP_LIMIT_PCT:-85}
chmod +x "$SRC/scripts/nibepi_restart.sh"

sudo tee /etc/systemd/system/nibepi-restart.service >/dev/null <<EOF
[Unit]
Description=NibePi restart when swap is high
After=docker.service

[Service]
Type=oneshot
Environment=SWAP_LIMIT_PCT=$LIMIT
ExecStart=$SRC/scripts/nibepi_restart.sh
TimeoutStartSec=90min
EOF

sudo tee /etc/systemd/system/nibepi-restart.timer >/dev/null <<'EOF'
[Unit]
Description=NibePi daily check, restart only when swap is high

[Timer]
OnCalendar=*-*-* 03:30:00

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nibepi-restart.timer
sudo systemctl start nibepi-restart.timer
systemctl list-timers nibepi-restart.timer --no-pager | sed -n 2p
echo "Log: /opt/nibepi/tmp/restart.log   Zkouska bez restartu: sudo DRY_RUN=1 $SRC/scripts/nibepi_restart.sh"
