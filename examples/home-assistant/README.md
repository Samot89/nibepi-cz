# Ceny a FVE přetoky z Home Assistantu

Automatizace v [nibepi_mqtt.yaml](nibepi_mqtt.yaml) posílají z Home Assistantu do
NibePi přes MQTT aktuální cenu elektřiny, hodinový ceník a přetoky z FVE. NibePi
podle nich posouvá topnou křivku a plánuje ohřev TUV.

🇬🇧 English: [README.en.md](README.en.md)

## Co je v souboru

| Část | Co dělá | MQTT topic |
|---|---|---|
| `NibePi - nákupní cena -> MQTT` | při každé změně pošle aktuální cenu v Kč/kWh | `nibepi/price/czk` |
| `NibePi - hodinový ceník -> MQTT` | pošle hodinové průměry na dnes a zítra pro VV-AI | `nibepi/price/czk_hourly` |
| `mqtt_statestream` | posílá pokojovou teplotu do NibePi | `homeassistant/sensor/<entita>/state` |
| senzor `PV surplus average` | vyhlazuje přetoky, aby je mraky nepřepínaly | |
| `NibePi - FVE přetoky -> MQTT` | pošle vyhlazené přetoky ve W | `nibepi/solar/surplus` |
| `NibePi - boost TUV při záporné ceně` | volitelné: ohřeje TUV při záporné ceně | `nibe/modbus/48132/set` |

## Co je potřeba

- MQTT integrace v Home Assistantu připojená ke stejnému brokeru jako NibePi.
- Senzor ceny s 15minutovými hodnotami v atributech, například z integrace
  CZ Energy Spot Prices. Hodinový ceník s jiným formátem atributů fungovat nebude.
- Senzor pokojové teploty pro řízení podle vnitřní teploty.
- Pro FVE boost senzor okamžitých přetoků do sítě ve W.

## Instalace

1. Uložte soubor jako `config/packages/nibepi.yaml` a v `configuration.yaml` zapněte:

   ```yaml
   homeassistant:
     packages: !include_dir_named packages
   ```

   Můžete také zkopírovat senzor a automatizace do vlastních souborů.

2. Nahraďte ID entit svými:

   | V souboru | Čím nahradit |
   |---|---|
   | `sensor.current_buy_electricity_price_15min` | cena, kterou platíte za kWh, včetně poplatků |
   | `sensor.grid_export_power` | okamžité přetoky do sítě ve W |
   | `sensor.indoor_temperature` | pokojová teplota, stejná entita jako v průvodci nastavením |
   | `sensor.current_spot_electricity_hour_order` | pořadí hodiny podle ceny (jen boost při záporné ceně) |
   | `sensor.nibe_vvm320_temporary_lux_2` | registr 48132 vašeho čerpadla (jen boost při záporné ceně) |

   `mqtt_statestream` může být v `configuration.yaml` jen jednou. Pokud už ho používáte,
   přidejte entitu do stávající konfigurace.

   Boost při záporné ceně nepotřebujete? Celou poslední automatizaci smažte.

3. Zkontrolujte konfiguraci a restartujte Home Assistant.

4. V dashboardu NibePi otevřete **Cena elektřiny**:
   - **Zdroj cen** nastavte na *Home Assistant (MQTT)*.
   - Ve skupině **Home Assistant (MQTT)** nastavte prahy cenových hladin.
   - Ve skupině **FVE boost** zapněte boost a nastavte prahy přetoků.

5. Ověřte, že v MQTT Exploreru nebo v *Vývojářské nástroje → MQTT* chodí hodnoty
   na výše uvedené topicy.

## FVE boost

Přetok od hodnoty **Přetok od (W)** zvýší cenovou hladinu o stupeň a při řízení
VV-AI ohřeje TUV na vypínací teplotu Normal. Od hodnoty **Velký přetok od (W)**
platí nejnižší cenová hladina a TUV se ohřeje na vyšší z teplot Lux a Normal.

Práh nastavte podle skutečného příkonu čerpadla při ohřevu. Při příliš nízkém prahu
kupujete většinu energie ze sítě. Přetoky se měří až po spotřebě domu, takže po
rozběhu kompresoru klesnou a ohřev může skončit dřív.

## Poznámky

- Když senzor přetoků hlásí `unknown`, automatizace pošle 0 W.
- Hodnoty jsou retained, takže je NibePi dostane i po svém restartu.
- Více k nastavení je v [hlavním README](../../README.md#ceny-a-fve-z-home-assistantu).
