// Copyright (C) 2025 Toit contributors.
// Use of this source code is governed by an MIT-style license that can be found
// in the LICENSE file.

import encoding.tison
import system.assets
import dhtxx.provider

install-from-args_ args/List:
  if args.size != 2:
    throw "Usage: main <pin> <variant>"
  pin := int.parse args[0]
  variant := args[1]
  if variant != "11" and variant != "22":
    throw "Invalid variant: $variant. Must be either '11' or '22'."
  provider.install pin --variant=variant

install-from-assets_ configuration/Map:
  pin := configuration.get "pin"
  if not pin: throw "No 'pin' found in assets."
  if pin is not int: throw "Pin must be an integer."
  variant := configuration.get "variant"
  if not variant: throw "No 'variant' found in assets."
  if variant != "11" and variant != "22":
    throw "Variant ID must be either the string '11' or '22'."
  provider.install pin --variant=variant

main args:
  // Arguments take priority over assets.
  if args.size != 0:
    install-from-args_ args
    return

  decoded := assets.decode
  ["configuration", "artemis.defines"].do: | key/string |
    configuration := decoded.get key
    if configuration:
      install-from-assets_ configuration
      return

  throw "No configuration found."
