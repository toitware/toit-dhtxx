// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import .driver_ as driver

/**
Driver for the DHT11 sensor.

Should also work for compatible sensors like the DHT12 or KY-015.
*/
class Dht11 extends driver.Driver:
  static HUMIDITY-INTEGRAL-PART_    ::= 0
  static HUMIDITY-DECIMAL-PART_     ::= 1
  static TEMPERATURE-INTEGRAL-PART_ ::= 2
  static TEMPERATURE-DECIMAL-PART_  ::= 3

  /** Deprecated. Channel ids can't be used anymore and are ignored. */
  constructor pin/gpio.Pin --in-channel-id/int --out-channel-id/int?=null --max-retries/int:
    return Dht11 pin --max-retries=max-retries

  /** Deprecated. Channel ids can't be used anymore and are ignored. */
  constructor pin/gpio.Pin --out-channel-id/int --max-retries/int:
    return Dht11 pin --max-retries=max-retries

  /**
  Constructs an instance of the DHT11 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. Allocates
    two RMT channels, one for reading, and one for writing.

  When the communication between the DHT11 and the device is flaky tries up to
    $max-retries before giving up.
  */
  constructor pin/gpio.Pin --max-retries/int=3:
    super pin --max-retries=max-retries

  parse-temperature_ data/ByteArray -> float:
    return data[TEMPERATURE-INTEGRAL-PART_].to-float + data[TEMPERATURE-DECIMAL-PART_] * 0.1

  parse-humidity_ data/ByteArray -> float:
    return data[HUMIDITY-INTEGRAL-PART_].to-float + data[HUMIDITY-DECIMAL-PART_] * 0.1
