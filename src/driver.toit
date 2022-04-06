// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import rmt
import gpio

class DhtResult:
  /** Temperature read from the DHTxx sensor in degrees Celcius. */
  temperature/float

  /** Humidity read from the DHTxx sensor. */
  humidity/float

  constructor.init_ .temperature .humidity:

  /** See $super.*/
  operator == other/any -> bool:
    return other is DhtResult and temperature == other.temperature and humidity == other.humidity

  hash_code -> int:
    return (temperature * 10).to_int * 11 + (humidity * 10).to_int * 13

  /** See $super. */
  stringify -> string:
    return "T: $(%.2f temperature), H: $(%.2f humidity)"

abstract class Driver:
  static HUMIDITY_INTEGRAL_PART_    ::= 0
  static HUMIDITY_DECIMAL_PART_     ::= 1
  static TEMPERATURE_INTEGRAL_PART_ ::= 2
  static TEMPERATURE_DECIMAL_PART_  ::= 3
  static CHECKSUM_PART_             ::= 4

  rx_/rmt.Channel
  tx_/rmt.Channel
  max_retries_/int

  ready_time_/Time? := null

  constructor pin/gpio.Pin --rx_channel_num/int --tx_channel_num/int --max_retries/int:
    max_retries_ = max_retries
    rx_ = rmt.Channel pin rx_channel_num
    tx_ = rmt.Channel pin tx_channel_num

    tx_.config_tx --idle_level=1
    rx_.config_rx --filter_ticks_thresh=20 --idle_threshold=18_020 --rx_buffer_size=512
    tx_.config_bidirectional_pin

    ready_time_ = Time.now + (Duration --s=1)

  /** Reads the humidity and temperature. */
  read -> DhtResult:
    data := read_data_

    return DhtResult.init_
        parse_temperature_ data
        parse_humidity_ data

  /** Reads the temperature. */
  read_temperature -> float:
    return parse_temperature_ read_data_

  /** Reads the humidity. */
  read_humidity -> float:
    return parse_humidity_ read_data_

  abstract parse_temperature_ data/ByteArray -> float
  abstract parse_humidity_ data/ByteArray -> float

  /** Checks that the data's checksum matches the humidity and temperature data. */
  check_checksum_ data/ByteArray:
    if not (data.size == 5 and (data[0] + data[1] + data[2] + data[3]) & 0xFF == data[4]):
      throw "Invalid checksum"

  read_data_ -> ByteArray:
    (max_retries_ - 1).repeat:
      catch: return read_data_no_catch_
    return read_data_no_catch_

  /**
  Reads the data from the DHTxx.

  Returns 5 bytes: 2 bytes humidity, 2 bytes temperature, 1 byte checksum. The
    interpretation of humidity and temperature is sensor specific.

  The DHTxx receiver must send the expected signals.
  */
  read_data_no_catch_ -> ByteArray:
    if ready_time_: wait_for_ready_

    transmit := rmt.Signals.alternating --first_level=0 [18_000,0]
    receive := rmt.Signals.alternating --first_level=1 [5_000]
    received_signals := rmt.transmit_and_receive --rx=rx_ --tx=tx_ 178 --receive=receive --transmit=transmit

    // We need to receive at least 82 signals.
    // DHT signal begin transmission:          2 signals
    // DHT transmit 40 bit, 2 signals each:   80 signals
    //                                        ----------
    // Total                                  82 signals
    if received_signals.size < 40 * 2 + 2: throw "insufficient signals from DHT"

    result_data := ByteArray 5: 0
    40.repeat:
      bit := (received_signals.signal_period 1 + 2 * it + 1) > 32 ? 1 : 0
      index := it / 8
      result_data[index] <<= 1
      result_data[index] = result_data[index] | bit

    check_checksum_ result_data
    return result_data

  wait_for_ready_:
    duration_until_ready := ready_time_.to_now
    if duration_until_ready > Duration.ZERO: sleep duration_until_ready

    ready_time_ = null
