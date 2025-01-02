// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import io show BIG_ENDIAN
import .driver_ as driver

/**
Driver for the DHT22 sensor.

Should also work for compatible sensors like the DHT33, AM2320, AM2321, or AM2322.
*/
class Dht22 extends driver.Driver:
  static HUMIDITY_INDEX_    ::= 0
  static TEMPERATURE_INDEX_ ::= 2

  /**
  Constructs an instance of the Dht22 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. It allocates
    two RMT channels. If the $in_channel_id and/or $out_channel_id is provided, uses
    those channels, otherwise picks the first free ones.
  When the communication between the DHT22 and the device is flaky tries up to
    $max_retries before giving up.
  */
  constructor pin/gpio.Pin --in_channel_id/int?=null --out_channel_id/int?=null --max_retries/int=3:
    super pin --in_channel_id=in_channel_id --out_channel_id=out_channel_id --max_retries=max_retries

  parse_temperature_ data/ByteArray -> float:
    // The temperature is a big-endian 16-bit integer.
    // Some sensors use the first bit to indicate the sign of the temperature; others
    // encode the value as 2's complement.
    // Since valid temperature values can only be in a small range, we can use the
    // second bit to determine which approach the sensor uses.
    byte1 := data[TEMPERATURE_INDEX_]
    temperature10/int := ?
    if (byte1 & 0x80 == 0) or (byte1 & 0x04 == 1):
      // The temperature is positive or the sensor uses 2's complement.
      temperature10 = BIG-ENDIAN.int16 data TEMPERATURE_INDEX_
    else:
      // The temperature is negative, but the sensor uses the first bit to indicate the sign.
      temperature10 = BIG-ENDIAN.uint16 data TEMPERATURE_INDEX_
      temperature10 = -(temperature10 & 0x7FFF)
    return temperature10 * 0.1

  parse_humidity_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data HUMIDITY_INDEX_) * 0.1
