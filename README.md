# DHTxx

Drivers for the DHT11 and DHT22 (aka AM2302 or RHT03) humidity and temperature sensors.

The DHT22 is a more luxurious version of the DHT11, providing more accurate readings.

Both use one wire to communicate with the host. The protocol is similar, but the interpretation of
the data is different. As such, the DHT11 and DHT22 drivers are not interchangeable but share a
lot of code.

## Implementation details

The DHT11 and DHT22 drivers are timing sensitive, and the drivers are therefore implemented using the RMT controller which allows for precise timings.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/toitware/toit-dhtxx/issues
