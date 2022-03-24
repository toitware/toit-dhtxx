// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import rmt
import .driver as driver
import binary show BIG_ENDIAN

class Driver extends driver.Driver:

  constructor --rx/rmt.Channel --tx/rmt.Channel:
    super --rx=rx --tx=tx

  temperature_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data driver.Driver.TEMPERATURE_INTEGRAL_PART_) / 10.0

  humidity_ data/ByteArray -> float:
    return (BIG_ENDIAN.uint16 data driver.Driver.HUMIDITY_INTEGRAL_PART_) / 10.0
