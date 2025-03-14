// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import io show BIG-ENDIAN
import .driver_ as driver

/**
Driver for the DHT22 sensor.

Should also work for compatible sensors like the DHT33, AM2320, AM2321, or AM2322.
*/
class Dht22 extends driver.Driver:
  static HUMIDITY-INDEX_    ::= 0
  static TEMPERATURE-INDEX_ ::= 2

  /**
  Constructs an instance of the Dht22 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. It allocates
    two RMT channels. If the $in-channel-id and/or $out-channel-id is provided, uses
    those channels, otherwise picks the first free ones.
  When the communication between the DHT22 and the device is flaky tries up to
    $max-retries before giving up.
  */
  constructor pin/gpio.Pin --in-channel-id/int?=null --out-channel-id/int?=null --max-retries/int=3:
    super pin --in-channel-id=in-channel-id --out-channel-id=out-channel-id --max-retries=max-retries

  parse-temperature_ data/ByteArray -> float:
    // The temperature is a big-endian 16-bit integer.
    // Some sensors use the first bit to indicate the sign of the temperature; others
    // encode the value as 2's complement.
    // Since valid temperature values can only be in a small range, we can use the
    // second bit to determine which approach the sensor uses.
    // If the first two bits were 1 and the sensor wasn't using 2's complement, then
    // the temperature would be lower than -64 degrees which is outside the supported
    // range.
    byte1 := data[TEMPERATURE-INDEX_]
    temperature10/int := ?
    if (byte1 & 0x80 == 0) or (byte1 & 0x40 == 1):
      // The temperature is positive or the sensor uses 2's complement.
      temperature10 = BIG-ENDIAN.int16 data TEMPERATURE-INDEX_
    else:
      // The temperature is negative, but the sensor uses the first bit to indicate the sign.
      temperature10 = BIG-ENDIAN.uint16 data TEMPERATURE-INDEX_
      temperature10 = -(temperature10 & 0x7FFF)
    return temperature10 * 0.1

  parse-humidity_ data/ByteArray -> float:
    return (BIG-ENDIAN.uint16 data HUMIDITY-INDEX_) * 0.1
