#!/bin/bash
# Restarts the NibePi container when swap use is high (Pi Zero 2 W has 512 MB RAM;
# Node-RED keeps a large part of its heap in swap and use can creep up over weeks).
# Run daily by nibepi-restart.timer (see install_restart_timer.sh); most nights it
# only logs that no restart is needed.
#
# Before restarting it waits (max 60 min) until the pump is not heating hot water and
# no one-time hot water boost (48132) is running. The ~40 s Modbus gap makes the pump
# raise alarm 251 (communication error); NibePi resets it by itself after start, the
# script only waits for that and sends the reset once more if needed. No other alarm
# is ever reset.
#
# Settings (environment variables):
#   SWAP_LIMIT_PCT  restart at this swap use in %          (default 85)
#   CONTAINER       container name                         (default nibepi)
#   LOG             log file                               (default /opt/nibepi/tmp/restart.log)
#   DRY_RUN=1       check and read registers, do not restart
SWAP_LIMIT_PCT=${SWAP_LIMIT_PCT:-85}
CONTAINER=${CONTAINER:-nibepi}
LOG=${LOG:-/opt/nibepi/tmp/restart.log}
[ "$DRY_RUN" = "1" ] || exec >>"$LOG" 2>&1

# Read one register through NibePi over MQTT (<topic><reg>/get); prints the value or nothing.
reg() {
    docker exec -i "$CONTAINER" node - "$1" <<'JS' 2>/dev/null
const fs = require('fs');
const mqtt = require('/usr/src/nibepi/node_modules/mqtt');
const c = JSON.parse(fs.readFileSync('/etc/nibepi/config.json', 'utf8')).mqtt;
const reg = process.argv[2];
const client = mqtt.connect(`mqtt://${c.host}:${c.port}`, { username: c.user, password: c.pass, clientId: 'restart_' + Date.now() });
client.on('connect', () => { client.subscribe(c.topic + reg); setTimeout(() => client.publish(c.topic + reg + '/get', ''), 500); });
client.on('message', (t, m) => { console.log(m.toString()); client.end(); process.exit(0); });
setTimeout(() => process.exit(1), 8000);
JS
}
# Write one register through NibePi over MQTT (<topic><reg>/set).
reg_set() {
    docker exec -i "$CONTAINER" node - "$1" "$2" <<'JS' 2>/dev/null
const fs = require('fs');
const mqtt = require('/usr/src/nibepi/node_modules/mqtt');
const c = JSON.parse(fs.readFileSync('/etc/nibepi/config.json', 'utf8')).mqtt;
const [reg, value] = process.argv.slice(2);
const client = mqtt.connect(`mqtt://${c.host}:${c.port}`, { username: c.user, password: c.pass, clientId: 'restart_' + Date.now() });
client.on('connect', () => client.publish(c.topic + reg + '/set', String(value), () => { client.end(); process.exit(0); }));
setTimeout(() => process.exit(1), 8000);
JS
}

read -r swap_total swap_used < <(free -m | awk '/Swap/{print $2, $3}')
if [ -z "$swap_total" ] || [ "$swap_total" -eq 0 ]; then
    echo "$(date '+%F %T') bez swapu, restart neni potreba"; exit 0
fi
pct=$(( swap_used * 100 / swap_total ))
if [ "$pct" -lt "$SWAP_LIMIT_PCT" ] && [ "$DRY_RUN" != "1" ]; then
    echo "$(date '+%F %T') swap $swap_used/$swap_total MB ($pct %) < $SWAP_LIMIT_PCT %, restart neni potreba"
    exit 0
fi
echo "=== $(date '+%F %T') swap $swap_used/$swap_total MB ($pct %)"

# 1) Wait until no hot water heating (43086 Prio 20 = hot water) and no one-time boost.
for i in $(seq 1 30); do
    prio=$(reg 43086); boost=$(reg 48132)
    if [ -n "$prio" ] && [ "$prio" != "20" ] && [ "$boost" = "0" ]; then break; fi
    echo "$(date +%T) ceka: prio=$prio boost=$boost"
    [ "$DRY_RUN" = "1" ] && break
    sleep 120
done
if [ "$DRY_RUN" = "1" ]; then
    echo "DRY_RUN: prio=$prio boost=$boost alarm=$(reg 45001), restart vynechan"; exit 0
fi
if [ -z "$prio" ] || [ "$prio" = "20" ] || [ "$boost" != "0" ]; then
    echo "$(date +%T) TUV se ohriva nebo NibePi neodpovida, restart odlozen"; exit 0
fi

# 2) Restart.
docker restart "$CONTAINER" >/dev/null && echo "$(date +%T) restartovano"

# 3) Wait until NibePi answers again (max 5 min).
for i in $(seq 1 30); do
    sleep 10
    a=$(reg 45001)
    [ -n "$a" ] && break
done
echo "$(date +%T) NibePi odpovida, alarm=$a"

# 4) Max 10 min: wait for the Modbus communication alarm (251) to clear. Nothing else is reset.
reset_sent=0
for i in $(seq 1 20); do
    a=$(reg 45001)
    [ "$a" != "251" ] && break
    if [ "$reset_sent" = "0" ]; then reg_set 45171 1; reset_sent=1; echo "$(date +%T) alarm 251, reset odeslan"; fi
    sleep 30
done
echo "=== $(date '+%F %T') konec, alarm=$(reg 45001), swap $(free -m | awk '/Swap/{print $3}') MB"
