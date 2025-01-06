// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import dhtxx
import gpio

GPIO-PIN-NUM ::= 14

main:
  pin := gpio.Pin GPIO-PIN-NUM
  driver := dhtxx.Dht22 pin

  (Duration --s=1).periodic:
    print driver.read
