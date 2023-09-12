// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import dhtxx
import gpio

GPIO_PIN_NUM ::= 14

main:
  pin := gpio.Pin GPIO_PIN_NUM
  driver := dhtxx.Dht11 pin

  (Duration --s=1).periodic:
    print driver.read
