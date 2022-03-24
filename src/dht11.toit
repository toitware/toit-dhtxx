// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import rmt
import .driver as driver

class Driver extends driver.Driver:

  constructor --rx/rmt.Channel --tx/rmt.Channel:
    super --rx=rx --tx=tx

  temperature_ data/ByteArray -> float:
    return data[driver.Driver.TEMPERATURE_INTEGRAL_PART_].to_float

  humidity_ data/ByteArray -> float:
    return data[driver.Driver.HUMIDITY_INTEGRAL_PART_].to_float
