# nibepi-docker (CZ fork)

Container packaging for NibePi, a Node-RED controller for Nibe F-series heat
pumps, adapted for the Czech Republic and an RS485 HAT on a Raspberry Pi.

🇨🇿 **Česky:** [README.cs.md](README.cs.md)

## Lineage

| | |
|---|---|
| [anerdins](https://github.com/anerdins) | original NibePi (up to 1.2.1) |
| [fnordpojk](https://github.com/fnordpojk) | NibePi 2.0: Docker image, Node-RED 5 / Node 24, work from ahsberg and pizzihelmet (VV-AI, pool) |
| this fork | changes below |

The full history of both is kept in each repository. None of the upstream
authors are involved in this fork.

## What this fork adds

- **RS485 HAT in Docker.** The upstream image targets a NibeGW gateway over UDP
  and does not install the core's own dependencies, so `serialport` was missing
  and `connection.enable: "serial"` could not work. The Dockerfile now installs
  them; the container gets `/dev/ttyAMA0`.
- **Price from Home Assistant (`price.source: "mqtt_ha"`).** The built-in price
  sources (Tibber, elprisetjustnu.se) only cover the Nordics. This one takes the
  current price in CZK/kWh from MQTT, published by Home Assistant, with your own
  thresholds for the five price levels.
- **PV surplus boost.** A PV export reading on MQTT raises the price level
  (≥ 1500 W → VERY_CHEAP, ≥ 500 W → one step up). Above 16 °C outdoors only hot
  water is boosted, not heating.
- **Open-Meteo forecast.** SMHI only covers Scandinavia; forecast control now
  uses Open-Meteo.

Repositories:

| directory | repository |
|---|---|
| `nibepi/` | [Samot89/nibepi-backend](https://github.com/Samot89/nibepi-backend) — the core: protocol, register handling, MQTT |
| `node-red-contrib-nibepi/` | [Samot89/node-red-contrib-nibepi](https://github.com/Samot89/node-red-contrib-nibepi) — the Node-RED nodes and dashboard logic |
| `/data` (run time) | [Samot89/nibepi-flow](https://github.com/Samot89/nibepi-flow) — the flows |

## Quick start (Raspberry Pi with RS485 HAT)

```sh
git clone https://github.com/Samot89/nibepi-docker.git
cd nibepi-docker
./scripts/setup_pi.sh          # Docker, repos, UART, image build
cp examples/config.example.json /opt/nibepi/etc/nibepi/config.json   # then edit it
sudo reboot
./scripts/run_nibepi.sh
```

Then open `http://<pi>:1880/ui`.

- `scripts/run_nibepi_test.sh` runs NibePi without the pump, next to an existing
  NibePi, without touching its Home Assistant entities.
- `examples/home-assistant/nibepi_mqtt.yaml` is the Home Assistant side: price
  and PV surplus to MQTT.

### config.json for mqtt_ha

```json
"connection": { "enable": "serial", "series": "fSeries" },
"serial": { "port": "/dev/ttyAMA0" },
"price": {
  "enable": true,
  "source": "mqtt_ha",
  "mqtt_ha_thresholds": { "very_cheap": 3.5, "cheap": 5, "normal": 7, "expensive": 9 },
  "solar_thresholds": { "very_cheap": 1500, "cheap": 500, "summer_temp": 16 }
}
```

Prices are compared with `<`: below `very_cheap` is VERY_CHEAP, below `expensive`
is EXPENSIVE, anything higher is VERY_EXPENSIVE. The curve offset for each level
comes from the usual `heat_*_s1` settings.

The source can also be picked in the dashboard (Price → Datasource →
"Home Assistant (MQTT)"). The thresholds are set in `config.json` only; edit it
with the container stopped, as NibePi writes its in-memory config back.

## Czech dashboard

Settings → Language → **Čeština**. Setting labels and help texts follow the
selected language; tab and group names, which upstream had in Swedish only, are
in Czech. Log messages from the core are still in Swedish.

---

The rest of this file is the upstream documentation.

## Setting up

```sh
git clone https://github.com/Samot89/nibepi-docker.git
cd nibepi-docker
git clone https://github.com/Samot89/nibepi-backend.git nibepi
git clone https://github.com/Samot89/node-red-contrib-nibepi.git
```

The flows are a third repository,
[Samot89/nibepi-flow](https://github.com/Samot89/nibepi-flow). It is not
built into the image — it is bind-mounted at run time as `/data`, because
Node-RED rewrites `flows.json` whenever you edit the dashboard.

## Building

```sh
docker build -t nibepi-nodered .
```

The image installs the two packages from the local directories rather than from
git, so an edit in either checkout shows up in the next build without committing
anything. That is deliberate: it is the loop for testing against a real pump.

## Running

With an RS485 HAT, use `scripts/run_nibepi.sh`. With a NibeGW gateway:

```sh
docker run -dit --name nibepi --restart unless-stopped \
  -v /opt/nibepi/data/nibepi-flow:/data \
  -v /opt/nibepi/etc/nibepi:/etc/nibepi \
  -v /opt/nibepi/tmp:/tmp \
  -p 1880:1880 \
  -p 9999:9999/udp \
  nibepi-nodered
```

A fixed name means the same command will not simply run again after a
rebuild. Replace the container with:

```sh
docker stop nibepi && docker rm nibepi
```

| mount | holds |
|---|---|
| `/data` | Node-RED's own directory: `flows.json`, `settings.js`, installed nodes. A clone of nibepi-flow. |
| `/etc/nibepi` | NibePi's state: `config.json`, saved graphs, the VV-AI profile. Must persist and must be writable. |
| `/tmp` | `nibepi.log`, the debug log. Mount it only if you want to read the log from the host. |

| port | for |
|---|---|
| `1880/tcp` | the Node-RED editor and dashboard |
| `9999/udp` | inbound frames from the NibeGW gateway |

Outbound, NibePi sends read requests to the gateway on UDP **10000** and writes
on UDP **10001**, from source port 9999. Those need no published port, but the
gateway has to accept them. With
[elupus/esphome-nibe](https://github.com/elupus/esphome-nibe) that means the
Docker host's address must appear in the `source:` list, and `read_port` /
`write_port` must be `10000` / `10001` to match.

## NIBEPI_DOCKER

The image sets `NIBEPI_DOCKER=1`. Without it the core assumes a bare Raspberry Pi
with a read-only SD card and brackets every config write in
`sudo mount -o remount,rw /`, which fails inside a container and loses the write
silently. Bare-Pi installs leave the variable unset.
