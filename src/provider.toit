// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import sensors.providers

import .driver_ as dhtxx
import .dht11 as dht11
import .dht22 as dht22

NAME-PREFIX ::= "toit.io/dht"
MAJOR ::= 1
MINOR ::= 0

class TemperatureSensor
    implements
      providers.TemperatureSensor-v1
      providers.HumiditySensor-v1:
  pin_/gpio.Pin? := ?
  sensor_/dhtxx.Driver? := ?

  constructor.dht11 pin/int:
    pin_ = gpio.Pin pin
    sensor_ = dht11.Dht11 pin_

  constructor.dht22 pin/int:
    pin_ = gpio.Pin pin
    sensor_ = dht22.Dht22 pin_

  temperature-read -> float?:
    return sensor_.read-temperature

  humidity-read -> float:
    return sensor_.read-humidity

  close -> none:
    if sensor_:
      sensor_.close
      sensor_ = null
    if pin_:
      pin_.close
      pin_ = null

install-dht11 pin/int -> providers.Provider:
  return install pin --variant="11"

install-dht22 pin/int -> providers.Provider:
  return install pin --variant="22"

/**
Installs the given DHTxx sensor.

The $variant argument must be either "11" or "22".
*/
install pin/int --variant/string -> providers.Provider:
  if variant != "11" and variant != "22":
    throw "Invalid variant: $variant. Must be either '11' or '22'."
  name := "$NAME-PREFIX$variant"
  provider := providers.Provider name
      --major=MAJOR
      --minor=MINOR
      --open=:: variant == "11" ? TemperatureSensor.dht11 pin : TemperatureSensor.dht22 pin
      --close=:: it.close
      --handlers=[providers.TemperatureHandler-v1, providers.HumidityHandler-v1]
  provider.install
  return provider
