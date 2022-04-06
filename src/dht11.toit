// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import gpio
import rmt
import .driver as driver

/** Deprecated. Use $Dht11 instead. */
class Driver extends Dht11:
  /** Deprecated. Use $(Dht11.constructor --rx --tx --max_retries) instead. */
  constructor --rx/rmt.Channel --tx/rmt.Channel:
    super --rx=rx --tx=tx

class Dht11 extends driver.Driver:

  /**
  Constructs an instance of the Dht11 driver, using the given RMT channels.

  Both channels must operate on the pin that is connected to the DHT11's data pin.

  When the communication between the DHT11 and the device is flaky tries up to
    $max_retries before giving up.
  */
  constructor --rx/rmt.Channel --tx/rmt.Channel --max_retries/int=3:
    super --rx=rx --tx=tx --max_retries=max_retries

  /**
  Constructs an instance of the Dht11 driver.
  Uses RMT (ESP's Remote Control peripheral) to talk to the sensor. It allocates
    two RMT channels with the given $rx_channel_num and $tx_channel_num numbers.
    These RMT channels must be unused.
  When the communication between the DHT11 and the device is flaky tries up to
    $max_retries before giving up.
  */
  constructor pin/gpio.Pin --rx_channel_num/int=0 --tx_channel_num/int=1 --max_retries/int=3:
    rx_channel := rmt.Channel pin rx_channel_num
    tx_channel := rmt.Channel pin tx_channel_num
    super --rx=rx_channel --tx=tx_channel --max_retries=max_retries

  parse_temperature_ data/ByteArray -> float:
    return data[driver.Driver.TEMPERATURE_INTEGRAL_PART_].to_float

  parse_humidity_ data/ByteArray -> float:
    return data[driver.Driver.HUMIDITY_INTEGRAL_PART_].to_float
