# DHTxx

Drivers for the DHT11 and DHT22 humidity and temperature sensors.

The DHT11 and DHT22 drivers are almost the same. The only difference is how the humidity and temperature are extracted from the sensor data.

## Implementation details

The DHT11 and DHT22 drivers are timing sensitive, and the drivers are therefore implemented using the RMT controller which allows for precise timings.
