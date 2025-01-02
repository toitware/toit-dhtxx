// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import io show BIG_ENDIAN
import .driver_ as driver

class Dht22 extends driver.Driver:

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
    return (BIG_ENDIAN.uint16 data driver.Driver.TEMPERATURE_INTEGRAL_PART_) / 10.0

  parse_humidity_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data driver.Driver.HUMIDITY_INTEGRAL_PART_) / 10.0
