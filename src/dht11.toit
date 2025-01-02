// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import .driver_ as driver

/**
Driver for the DHT11 sensor.

Should also work for compatible sensors like the DHT12, or KY-015.
*/
class Dht11 extends driver.Driver:
  static HUMIDITY_INTEGRAL_PART_    ::= 0
  static HUMIDITY_DECIMAL_PART_     ::= 1
  static TEMPERATURE_INTEGRAL_PART_ ::= 2
  static TEMPERATURE_DECIMAL_PART_  ::= 3

  /**
  Constructs an instance of the Dht11 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. It allocates
    two RMT channels. If the $in_channel_id and/or $out_channel_id is provided, uses
    those channels, otherwise picks the first free ones.
  When the communication between the DHT11 and the device is flaky tries up to
    $max_retries before giving up.
  */
  constructor pin/gpio.Pin --in_channel_id/int?=null --out_channel_id/int?=null --max_retries/int=3:
    super pin --in_channel_id=in_channel_id --out_channel_id=out_channel_id --max_retries=max_retries

  parse_temperature_ data/ByteArray -> float:
    return data[TEMPERATURE_INTEGRAL_PART_].to-float + data[TEMPERATURE_DECIMAL_PART_] * 0.1

  parse_humidity_ data/ByteArray -> float:
    return data[HUMIDITY_INTEGRAL_PART_].to-float + data[HUMIDITY_DECIMAL_PART_] * 0.1
