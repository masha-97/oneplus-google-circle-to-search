#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/tools/plk110-assistant.sh"

require() { grep -Fq "$1" "$SCRIPT" || { echo "missing: $1" >&2; exit 1; }; }
reject() { ! grep -Fq "$1" "$SCRIPT" || { echo "forbidden: $1" >&2; exit 1; }; }

sh -n "$SCRIPT"
require 'ro.product.model PLK110'
require 'ro.product.device OP60FFL1'
require "ro.build.display.id 'PLK110_16.0.9.400(CN01)'"
require 'lens_ondevice_engine_feature_module'
require 'lens_ondevice_engine_play_ml_module'
require 'tclib_native_feature_module'
require 'shasum -a 256'
require 'Type INSTALL to continue'
require 'enable static scopes: system and com.google.android.googlequicksearchbox'
require 'KernelSU Manager'
reject 'fastboot'
reject 'dd '
reject 'rm -rf'
reject 'curl'
echo 'Installer assistant contract: PASS'
