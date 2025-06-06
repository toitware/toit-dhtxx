// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import dhtxx
import gpio

GPIO-PIN-NUM ::= 32

main:
  pin := gpio.Pin GPIO-PIN-NUM
  driver := dhtxx.Dht22 pin
  // On some versions of Toit/ESP-IDF it is necessary to sleep a bit before
  // reading the sensor for the first time.
  sleep --ms=300

  (Duration --s=1).periodic:
    print driver.read
