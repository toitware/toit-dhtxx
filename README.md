# Toit DHTxx

Drivers for the DHT11 and DHT22 humidity and temperature sensors.

The DHT11 and DHT22 drivers are almost the same. The only difference is how the humidity and temperature are extracted from the sensor data.

## Implementation details

The DHT11 and DHT22 drivers are timing sensitive which does not work well with Toit. Therefore, the drivers are implemented using the RMT controller which allows for precise timings.
