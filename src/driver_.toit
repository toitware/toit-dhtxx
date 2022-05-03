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

  channel_ /rmt.BidirectionalChannel
  max_retries_ /int

  ready_time_/Time? := ?

  constructor pin/gpio.Pin --in_channel_id/int?=null --out_channel_id/int?=null --max_retries/int:
    max_retries_ = max_retries

    channel_ = rmt.BidirectionalChannel pin
        --in_channel_id=in_channel_id
        --out_channel_id=out_channel_id
        --in_filter_ticks_threshold=20
        --in_idle_threshold=25_000 // 18_020
        --in_buffer_size=512

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
    max_retries_.repeat:
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

    // Pull low for 20ms to start the transmission.
    signals := rmt.Signals 1
    signals.set 0 --level=0 --period=20_000
    received_signals := channel_.write_and_read --during_read=signals 178

    // We need to receive at least 84 signals.
    // Initiate the transmission. Pull low:    1 signal
    // Pull high and hand over to the DHT:     1 signal
    // DHT signal begin transmission:          2 signals
    // DHT transmit 40 bit, 2 signals each:   80 signals
    //                                        ----------
    // Total                                  84 signals
    //
    // There should be a trailing 0 signal, followed by the end-marker, but we
    // don't care for them.
    if received_signals.size < 4 + 40 * 2:
      throw "insufficient signals from DHT"

    // Each bit starts with 50us low, followed by ~25us for 0 or ~70us for 1.
    // We only need to look at the 1s.

    offset := 5  // Skip over the initial handshake, and the 0 of the first bit.
    result_data := ByteArray 5: 0
    40.repeat:
      bit := (received_signals.period 2 * it + offset) > 32 ? 1 : 0
      index := it / 8
      result_data[index] <<= 1
      result_data[index] = result_data[index] | bit

    check_checksum_ result_data
    return result_data

  wait_for_ready_:
    duration_until_ready := ready_time_.to_now
    if duration_until_ready > Duration.ZERO: sleep duration_until_ready

    ready_time_ = null
