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

  hash-code -> int:
    return (temperature * 10).to-int * 11 + (humidity * 10).to-int * 13

  /** See $super. */
  stringify -> string:
    return "T: $(%.2f temperature), H: $(%.2f humidity)"

abstract class Driver:
  channel-in_    /rmt.Channel
  channel-out_   /rmt.Channel
  max-retries_   /int
  is-first-read_ /bool := true

  ready-time_/Time? := ?

  constructor pin/gpio.Pin --in-channel-id/int?=null --out-channel-id/int?=null --max-retries/int:
    max-retries_ = max-retries

    // The out channel must be configured before the in channel, so that make_bidirectional works.
    channel-out_ = rmt.Channel pin
        --output
        --channel-id=out-channel-id
        --idle-level=1
    channel-in_ = rmt.Channel --input pin
        --channel-id=in-channel-id
        --filter-ticks-threshold=20
        --idle-threshold=100

    rmt.Channel.make-bidirectional --in=channel-in_ --out=channel-out_

    ready-time_ = Time.now + (Duration --s=1)

  /** Reads the humidity and temperature. */
  read -> DhtResult:
    data := read-data_

    return DhtResult.init_
        parse-temperature_ data
        parse-humidity_ data

  /** Reads the temperature. */
  read-temperature -> float:
    return parse-temperature_ read-data_

  /** Reads the humidity. */
  read-humidity -> float:
    return parse-humidity_ read-data_

  abstract parse-temperature_ data/ByteArray -> float
  abstract parse-humidity_ data/ByteArray -> float

  /** Checks that the data's checksum matches the humidity and temperature data. */
  check-checksum_ data/ByteArray:
    if not (data.size == 5 and (data[0] + data[1] + data[2] + data[3]) & 0xFF == data[4]):
      throw "Invalid checksum"

  read-data_ -> ByteArray:
    attempts := max-retries_ + 1
    if is-first-read_:
      // Due to the way we set up the RMT channels, there might be some
      // pulses on the data line which can confuse the DHT. The very first
      // read thus sometimes fails.
      attempts++
      is-first-read_ = false
    attempts.repeat:
      catch --unwind=(it == attempts - 1):
        with-timeout --ms=1_000:
          return read-data-no-catch_
    unreachable

  /**
  Reads the data from the DHTxx.

  Returns 5 bytes: 2 bytes humidity, 2 bytes temperature, 1 byte checksum. The
    interpretation of humidity and temperature is sensor specific.

  The DHTxx receiver must send the expected signals.
  */
  read-data-no-catch_ -> ByteArray:
    if ready-time_: wait-for-ready_

    // Pull low for 20ms to start the transmission.
    start-signal := rmt.Signals 1
    start-signal.set 0 --level=0 --period=20_000
    channel-in_.start-reading
    channel-out_.write start-signal
    response := channel-in_.read
    if response.size == 2 and (response.period 0) == 0 and (response.period 1) == 0:
      // We are getting some spurious signals from the start signal,
      // which we just ignore.
      response = channel-in_.read
    channel-in_.stop-reading

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
    result-data := ByteArray 5: 0
    40.repeat:
      bit := (response.period 2 * it + offset) > 32 ? 1 : 0
      index := it / 8
      result-data[index] <<= 1
      result-data[index] = result-data[index] | bit

    check-checksum_ result-data
    return result-data

  wait-for-ready_:
    duration-until-ready := ready-time_.to-now
    if duration-until-ready > Duration.ZERO: sleep duration-until-ready

    ready-time_ = null
