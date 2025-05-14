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
  channel-in_    /rmt.In? := ?
  channel-out_   /rmt.Out? := ?
  max-retries_   /int
  is-first-read_ /bool := true

  ready-time_/Time? := ?

  constructor pin/gpio.Pin --max-retries/int:
    max-retries_ = max-retries

    channel-in_ = rmt.In pin --resolution=1_000_000
    channel-out_ = rmt.Out pin --resolution=1_000_000 --open-drain

    high-signal := rmt.Signals 1
    high-signal.set 0 --level=1 --period=20
    // Set the line to 1.
    channel-out_.write high-signal --done-level=1

    ready-time_ = Time.now + (Duration --s=1)

  close -> none:
    if channel-in_:
      channel-in_.close
      channel-in_ = null
    if channel-out_:
      channel-out_.close
      channel-out_ = null

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
          try:
            return read-data-no-catch_
          finally:
            if channel-in_.is-reading:
              channel-in_.reset
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
    // The resolution of the RMT is set to 1MHz, so the period is 1us.
    start-signal := rmt.Signals 1
    start-signal.set 0 --level=0 --period=20_000
    channel-in_.start-reading --min-ns=1_000 --max-ns=25_000_000
    channel-out_.write start-signal --done-level=1
    response := channel-in_.wait-for-data

    // We expect to see:
    // - the start signal (20ms of low).
    // - high after the start-signal (level=1, ~24-40us)
    // - DHT response signal (80us)
    // - DHT high after response signal (80us)
    // - all signals, each:
    //   * low: 50us
    //   * high: 26-28us for 0, or 70us for 1
    // - a trailing 0.

    if response.size < 4 + 40 * 2:
      throw "insufficient signals from DHT"

    if (response.level 0) != 0 or not 19_000 <= (response.period 0) <= 21_000:
      throw "start signal not detected"

    // Each bit starts with 50us low, followed by ~25us for 0 or ~70us for 1.
    // We only need to look at the 1s.

    offset := 5  // Skip over the start signal, initial handshake, and the 0 of the first bit.
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
