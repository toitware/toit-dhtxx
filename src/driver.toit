// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import rmt

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

  ready_time_/Time? := null

  constructor --rx/rmt.Channel --tx/rmt.Channel:
    rx_ = rx
    tx_ = tx

    tx_.config_tx --idle_level=1
    rx_.config_rx --filter_ticks_thresh=10 --idle_threshold=18_020 --rx_buffer_size=1024
    tx_.config_bidirectional_pin

    ready_time_ = Time.now + (Duration --s=1)

    /**
  Reads the humidity and temperature.

  Returns null if the sensor data is corrupt.
  */
  read -> DhtResult?:
    data := read_data_
    if not is_valid_crc_ data: return null

    return DhtResult.init_
        temperature_ data
        humidity_ data

  /**
  Reads the temperature.

  Returns null if the sensor data is corrupt.
  */
  read_temperature -> float?:
    data := read_data_
    if not is_valid_crc_ data: return null

    return temperature_ data

    /**
  Reads the humidity.

  Returns null if the sensor data is corrupt.
  */
  read_humidity -> float?:
    data := read_data_
    if not is_valid_crc_ data: return null

    return humidity_ data

  abstract temperature_ data/ByteArray -> float
  abstract humidity_ data/ByteArray -> float

  /** Whether the data checksum matches the humidity and temperature data. */
  is_valid_crc_ data/ByteArray -> bool:
    return data.size == 5 and (data[0] + data[1] + data[2] + data[3]) & 0xFF == data[4]

  /**
  Reads the data from the DHTxx.

  Returns 5 bytes: 2 bytes humidity, 2 bytes temperature, 1 byte checksum. The
    interpretation of humidity and temperature is sensor specific.

  The DHTxx receiver must send the expected signals.
  */
  read_data_ -> ByteArray:
    if ready_time_: wait_for_ready_

    signals := rmt.Signals.alternating --first_level=0 [18_000, 5_000]
    received_signals := rmt.transmit_and_receive --rx=rx_ --tx=tx_ 178 --receive=signals

    // We need to receive at least 84 signals.
    // We signal begin:                        2 signals
    // DHT signal begin transmission:          2 signals
    // DHT transmit 40 bit, 2 signals each:   80 signals
    //                                        ----------
    // Total                                  84 signals
    if received_signals.size < 40 * 2 + 4: throw "insufficient signals from DHT"

    result_data := ByteArray 5: 0
    40.repeat:
      bit := (received_signals.signal_period 4 + 2 * it + 1) > 32 ? 1 : 0
      index := it / 8
      result_data[index] <<= 1
      result_data[index] = result_data[index] | bit

    return result_data

  wait_for_ready_:
    duration_until_ready := ready_time_.to_now
    if duration_until_ready > Duration.ZERO: sleep duration_until_ready

    ready_time_ = null
