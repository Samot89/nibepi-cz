# Prices and PV surplus from Home Assistant

The automations in [nibepi_mqtt.yaml](nibepi_mqtt.yaml) send the current
electricity price, an hourly price list and the PV surplus from Home Assistant to
NibePi over MQTT. NibePi uses them to shift the heating curve and plan hot water.

🇨🇿 Česky: [README.md](README.md)

## Setup

1. Save the file as `config/packages/nibepi.yaml` and enable packages in
   `configuration.yaml`, or copy the sensor and the automations into your own files.
2. Replace the entity ids:

   | In the file | Replace with |
   |---|---|
   | `sensor.current_buy_electricity_price_15min` | the price you pay per kWh, with 15-minute values in its attributes |
   | `sensor.grid_export_power` | instantaneous export to grid in W |
   | `sensor.indoor_temperature` | room temperature, the same entity as in the setup questions |
   | `sensor.current_spot_electricity_hour_order` | the hour's price rank (negative price boost only) |
   | `sensor.nibe_vvm320_temporary_lux_2` | your pump's register 48132 (negative price boost only) |

3. Check the configuration and restart Home Assistant.
4. In the NibePi dashboard open the electricity price tab, set the price source to
   *Home Assistant (MQTT)*, then set the price thresholds and the PV boost.

Set the PV boost threshold to match what the pump actually draws when heating: with
a threshold that is too low, most of the energy comes from the grid. Surplus is
measured after the house's consumption, so it drops once the compressor starts and
heating may stop early.
