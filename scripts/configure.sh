#!/bin/bash
# Průvodce nastavením: zeptá se na pár údajů a vytvoří config.json ze vzoru.
# Spouští se sám z setup_pi.sh, jde spustit i znovu ručně. Před přepsáním
# existujícího configu se zeptá a uloží ho jako config.json.bak.

set -e

SRC=$(cd "$(dirname "$0")/.." && pwd)
export CONFIG=${NIBEPI_CONFIG:-/opt/nibepi/etc/nibepi/config.json}
export EXAMPLE=$SRC/examples/config.example.json

ask() { # proměnná, otázka, výchozí hodnota
    local answer
    read -r -p "$2${3:+ [$3]}: " answer || true
    printf -v "$1" '%s' "${answer:-$3}"
}

if [ -f "$CONFIG" ]; then
    ask OVERWRITE "Config už existuje, přepsat? (a/N)" "N"
    case "$OVERWRITE" in
        a|A|ano) cp "$CONFIG" "$CONFIG.bak"; echo "Záloha: $CONFIG.bak" ;;
        *) echo "Config ponechán."; exit 0 ;;
    esac
fi

echo "--- MQTT broker (např. Mosquitto add-on v Home Assistantu)"
ask MQTT_HOST "Adresa brokeru" ""
ask MQTT_PORT "Port" "1883"
ask MQTT_USER "Uživatel" ""
read -r -s -p "Heslo: " MQTT_PASS || true
echo
echo "--- Poloha domu pro předpověď (stačí přibližně, např. z mapy)"
ask LAT "Zeměpisná šířka" ""
ask LON "Zeměpisná délka" ""
echo "--- Čerpadlo"
ask PUMP "Model" "VVM320"
echo "--- Pokojové čidlo z Home Assistantu (prázdné = bez řízení podle čidla z HA)"
ask ENTITY "ID entity, např. sensor.obyvak_teplota" ""

if [ -z "$MQTT_HOST" ] || [ -z "$LAT" ] || [ -z "$LON" ]; then
    echo "Chybí adresa brokeru nebo poloha, config nevznikl. Spusťte průvodce znovu." >&2
    exit 1
fi

export MQTT_HOST MQTT_PORT MQTT_USER MQTT_PASS LAT LON PUMP ENTITY
python3 - <<'EOF'
import json, os

e = os.environ
c = json.load(open(e['EXAMPLE'], encoding='utf-8'))
c['mqtt'].update(host=e['MQTT_HOST'], port=e['MQTT_PORT'], user=e['MQTT_USER'], **{'pass': e['MQTT_PASS']})
c['home']['lat'] = e['LAT'].replace(',', '.')
c['home']['lon'] = e['LON'].replace(',', '.')
c['system']['pump'] = e['PUMP']

entity = e['ENTITY'].strip()
if entity:
    c['home']['inside_sensors'][0]['register'] = 'homeassistant/' + entity.replace('.', '/', 1) + '/state'
else:
    c['home']['inside_sensors'] = []
    c['indoor']['enable_s1'] = False
    c['price']['enable_temp_s1'] = False
    for section in ('indoor', 'price', 'weather', 'rmu'):
        c[section]['sensor_s1'] = ''

fd = os.open(e['CONFIG'], os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w', encoding='utf-8') as f:
    json.dump(c, f, indent=2, ensure_ascii=False)
EOF

echo "Config uložen: $CONFIG"
