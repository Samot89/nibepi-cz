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

   If you only have the spot price, compute the buy price in the templates as
   spot × 1.21 (VAT) + your supplier's fee incl. VAT.
3. Check the configuration and restart Home Assistant.
4. In the NibePi dashboard open the electricity price tab, set the price source to
   *Home Assistant (MQTT)*, then set the price thresholds and the PV boost.

NibePi ignores a price older than 60 minutes and then runs without price control
(no curve shift from price, hot water Normal). The price automation therefore also
republishes every 15 minutes, and a second automation clears the stored price when
the price sensor has been unavailable for 30 minutes.

Set the PV boost threshold to match what the pump actually draws when heating: with
a threshold that is too low, most of the energy comes from the grid. Surplus is
measured after the house's consumption, so it drops once the compressor starts and
heating may stop early.

## Daily price thresholds (optional)

Fixed thresholds stop fitting once prices shift with the seasons: in winter the
whole day is "expensive", in summer "cheap". The automation
`NibePi - cenové prahy podle dne -> MQTT` computes the thresholds every night (and
hourly as a fallback) from today's 15-minute prices: the cheapest 20 % of the day
are very cheap, the next 20 % cheap, the most expensive 25 % expensive and the most
expensive 10 % very expensive. Floors keep them sane: very cheap is always below
4.5 CZK, cheap always below 6 CZK, expensive starts at 8 CZK at the earliest and
very expensive at 10 CZK. Percentages and floors are variables at the top of the
automation.

NibePi prefers the MQTT thresholds over the ones in the dashboard, which stay as a
fallback (the dashboard does not show the MQTT ones). The PV boost still raises the
level on top. To turn it off, disable the automation and publish an empty retained
payload to the four `nibepi/price/thresholds/*` topics.
