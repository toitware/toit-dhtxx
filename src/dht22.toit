// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import binary show BIG_ENDIAN
import .driver as driver

class Dht22 extends driver.Driver:

  /**
  Constructs an instance of the Dht22 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. It allocates
    two RMT channels with the given $rx_channel_num and $tx_channel_num numbers.
    These RMT channels must be unused.
  When the communication between the DHT22 and the device is flaky tries up to
    $max_retries before giving up.
  */
  constructor pin/gpio.Pin --rx_channel_num/int=0 --tx_channel_num/int=1 --max_retries/int=3:
    super pin --rx_channel_num=rx_channel_num --tx_channel_num=tx_channel_num --max_retries=max_retries

  parse_temperature_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data driver.Driver.TEMPERATURE_INTEGRAL_PART_) / 10.0

  parse_humidity_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data driver.Driver.HUMIDITY_INTEGRAL_PART_) / 10.0
