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

  channel_in_    /rmt.Channel
  channel_out_   /rmt.Channel
  max_retries_   /int
  is_first_read_ /bool := true

  ready_time_/Time? := ?

  constructor pin/gpio.Pin --in_channel_id/int?=null --out_channel_id/int?=null --max_retries/int:
    max_retries_ = max_retries

    // The out channel must be configured before the in channel, so that make_bidirectional works.
    channel_out_ = rmt.Channel pin
        --output
        --channel_id=out_channel_id
        --idle_level=1
    channel_in_ = rmt.Channel --input pin
        --channel_id=in_channel_id
        --filter_ticks_threshold=20
        --idle_threshold=100

    rmt.Channel.make_bidirectional --in=channel_in_ --out=channel_out_

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
    attempts := max_retries_ + 1
    if is_first_read_:
      // Due to the way we set up the RMT channels, there might be some
      // pulses on the data line which can confuse the DHT. The very first
      // read thus sometimes fails.
      attempts++
      is_first_read_ = false
    attempts.repeat:
      catch --unwind=(it == attempts - 1):
        with_timeout --ms=1_000:
          return read_data_no_catch_
    unreachable

  /**
  Reads the data from the DHTxx.

  Returns 5 bytes: 2 bytes humidity, 2 bytes temperature, 1 byte checksum. The
    interpretation of humidity and temperature is sensor specific.

  The DHTxx receiver must send the expected signals.
  */
  read_data_no_catch_ -> ByteArray:
    if ready_time_: wait_for_ready_

    // Pull low for 20ms to start the transmission.
    start_signal := rmt.Signals 1
    start_signal.set 0 --level=0 --period=20_000
    channel_in_.start_reading
    channel_out_.write start_signal
    response := channel_in_.read
    if response.size == 2 and (response.period 0) == 0 and (response.period 1) == 0:
      // We are getting some spurious signals from the start signal.
      response = channel_in_.read
    channel_in_.stop_reading

    // We expect to see:
    // - high after the start-signal (level=1, ~24-40us)
    // - DHT response signal (80us)
    // - DHT high after response signal (80us)
    // - all signals, each:
    //   * low: 50us
    //   * high: 26-28us for 0, or 70us for 1
    // - a trailing 0.

    if response.size < 3 + 40 * 2:
      throw "insufficient signals from DHT"

    // Each bit starts with 50us low, followed by ~25us for 0 or ~70us for 1.
    // We only need to look at the 1s.

    offset := 4  // Skip over the initial handshake, and the 0 of the first bit.
    result_data := ByteArray 5: 0
    40.repeat:
      bit := (response.period 2 * it + offset) > 32 ? 1 : 0
      index := it / 8
      result_data[index] <<= 1
      result_data[index] = result_data[index] | bit

    check_checksum_ result_data
    return result_data

  wait_for_ready_:
    duration_until_ready := ready_time_.to_now
    if duration_until_ready > Duration.ZERO: sleep duration_until_ready

    ready_time_ = null
