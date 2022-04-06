// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import dhtxx.dht22
import gpio
import rmt

GPIO_PIN_NUM ::=  17

RX_CHANNEL_NUM ::= 0
TX_CHANNEL_NUM ::= 1

main:
  pin := gpio.Pin GPIO_PIN_NUM
  rx_channel := rmt.Channel pin RX_CHANNEL_NUM
  tx_channel := rmt.Channel pin TX_CHANNEL_NUM

  driver := dht22.Driver --rx=rx_channel --tx=tx_channel

  (Duration --s=5).periodic:
    print driver.read
