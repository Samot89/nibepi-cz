# NibePi v Dockeru – česká verze

Řízení tepelných čerpadel Nibe řady F (např. VVM320, F1255) z Raspberry Pi
přes RS485 HAT, s cenami elektřiny a FVE přetoky z Home Assistantu.

🇬🇧 English: [README.md](README.md)

## Odkud to je

| | |
|---|---|
| [anerdins](https://github.com/anerdins) | původní NibePi (do verze 1.2.1) |
| [fnordpojk](https://github.com/fnordpojk) | NibePi 2.0: Docker, Node-RED 5 / Node 24, práce od ahsberg a pizzihelmet (VV-AI, bazén) |
| tento fork | úpravy pro ČR (níže) |

Celá historie obou je v repozitářích zachovaná. Původní autoři se na tomto
forku nepodílejí, chyby proto prosím nehlaste u nich.

## Co tento fork přidává

- **RS485 HAT v Dockeru.** Původní image počítá s bránou NibeGW přes UDP a
  neinstaluje závislosti jádra, takže chyběl `serialport` a připojení přes
  sériový port (`connection.enable: "serial"`) nefungovalo.
- **Cena z Home Assistantu (`price.source: "mqtt_ha"`).** Vestavěné zdroje cen
  (Tibber, elprisetjustnu.se) jsou jen pro severské země. Tenhle bere aktuální
  cenu v Kč/kWh z MQTT, kam ji posílá Home Assistant, a podle vašich prahů z ní
  určí jednu z pěti cenových hladin.
- **FVE boost.** Přetoky z FVE posílané přes MQTT zvednou cenovou hladinu
  (≥ 1500 W → VERY_CHEAP, ≥ 500 W → o stupeň výš). Nad 16 °C venku se boostuje
  jen ohřev TUV, ne topení.
- **Předpověď z Open-Meteo.** SMHI pokrývá jen Skandinávii, prognózní regulace
  proto bere předpověď z Open-Meteo.

## Repozitáře

| repozitář | obsah |
|---|---|
| [nibepi-docker](https://github.com/Samot89/nibepi-docker) | Dockerfile, skripty, příklady (tento) |
| [nibepi-backend](https://github.com/Samot89/nibepi-backend) | jádro: komunikace s čerpadlem, registry, MQTT |
| [node-red-contrib-nibepi](https://github.com/Samot89/node-red-contrib-nibepi) | Node-RED nody: ceny, počasí, TUV, VV-AI |
| [nibepi-flow](https://github.com/Samot89/nibepi-flow) | Node-RED flows a dashboard |

## Co je potřeba

- Raspberry Pi (ověřeno na **Pi Zero 2 W**, stačí 512 MB RAM) s 64bit
  Raspberry Pi OS Lite (Debian 12 nebo 13)
- RS485 HAT na GPIO (UART na pinech 14/15), zapojený do čerpadla
- MQTT broker (např. Mosquitto add-on v Home Assistantu)

## Instalace

1. Naflashujte Raspberry Pi OS Lite přes Raspberry Pi Imager a v průvodci
   nastavte uživatele, WiFi (země CZ) a SSH.
2. Na Pi:

   ```sh
   git clone https://github.com/Samot89/nibepi-docker.git
   cd nibepi-docker
   ./scripts/setup_pi.sh
   ```

   Skript nainstaluje Docker, stáhne repozitáře do `/opt/nibepi/`, zapne UART
   pro HAT (`enable_uart=1`, `dtoverlay=disable-bt`, vypne sériovou konzoli)
   a sestaví image. Na Pi Zero 2 W to trvá zhruba 10–15 minut.

3. Config:

   ```sh
   cp examples/config.example.json /opt/nibepi/etc/nibepi/config.json
   nano /opt/nibepi/etc/nibepi/config.json
   ```

   Vyplňte hlavně `mqtt` (adresa brokeru, uživatel, heslo), `home.lat` / `home.lon`
   (souřadnice pro předpověď a východ a západ slunce) a `system.pump` (model
   čerpadla).

4. `sudo reboot` (kvůli UARTu), pak `./scripts/run_nibepi.sh`.
5. Dashboard je na `http://<ip-pi>:1880/ui`.

### Přechod ze starého NibePi

- Starý config se dá zkopírovat: `./scripts/run_nibepi.sh --copy-config pi@<stare-pi>`.
- **Obě NibePi nesmí běžet současně se stejným MQTT topicem.** Nová verze po
  připojení smaže v HA staré discovery entity a vytvoří jedno nové zařízení,
  takže se mohou změnit entity ID v HA (automatizace je pak potřeba upravit).
- Na zkoušku vedle starého NibePi (bez čerpadla, bez zásahu do HA) slouží
  `./scripts/run_nibepi_test.sh`.

## Ceny a FVE z Home Assistantu

V HA použijte [examples/home-assistant/nibepi_mqtt.yaml](examples/home-assistant/nibepi_mqtt.yaml).
Posílá do MQTT:

| topic | obsah |
|---|---|
| `nibepi/price/czk` | aktuální nákupní cena v Kč/kWh (např. z integrace CZ Energy Spot Prices) |
| `nibepi/solar/surplus` | průměrné FVE přetoky ve W |
| `nibepi/price/thresholds/*` | volitelně: prahy hladin, přepíší hodnoty z configu |

A v `config.json`:

```json
"price": {
  "enable": true,
  "source": "mqtt_ha",
  "mqtt_ha_thresholds": { "very_cheap": 3.5, "cheap": 5, "normal": 7, "expensive": 9 },
  "solar_thresholds": { "very_cheap": 1500, "cheap": 500, "summer_temp": 16 },
  "enable_heat_s1": true,
  "heat_very_cheap_s1": 3, "heat_cheap_s1": 2, "heat_normal_s1": 0,
  "heat_expensive_s1": -3, "heat_very_expensive_s1": -4
}
```

Cena pod `very_cheap` znamená VERY_CHEAP, pod `cheap` CHEAP, pod `normal`
NORMAL, pod `expensive` EXPENSIVE a cokoliv vyššího VERY_EXPENSIVE. Podle
hladiny se posune topná křivka o hodnotu `heat_*_s1`. Když cena v MQTT chybí,
posun se vrátí na 0 a TUV na Normal.

⚠️ **Zdroj `mqtt_ha` není v nabídce na stránce cen v dashboardu.** Když tam
vyberete jakýkoli zdroj, `mqtt_ha` se přepíše. Měňte ho jen v `config.json`
při zastaveném kontejneru (`sudo docker stop nibepi`).

## Aktualizace z upstreamu

```sh
cd /opt/nibepi/src/nibepi-docker/node-red-contrib-nibepi
git remote add fnordpojk https://github.com/fnordpojk/node-red-contrib-nibepi.git
git pull --rebase fnordpojk main
# stejně pro nibepi/ (fnordpojk/nibepi-backend) a nibepi-docker
cd /opt/nibepi/src/nibepi-docker && sudo docker build -t nibepi-nodered . && ./scripts/run_nibepi.sh
```

## Užitečné příkazy

```sh
sudo docker logs -f nibepi        # log
sudo docker restart nibepi        # restart
tail -f /opt/nibepi/tmp/nibepi.log  # debug log NibePi (když je zapnutý)
```
