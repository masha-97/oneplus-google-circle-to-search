#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$PROJECT_DIR/src/contextual_sidekey.c"
SERVICE="$PROJECT_DIR/module/service.sh"
MODULE="$PROJECT_DIR/module/module.prop"
CUSTOMIZE="$PROJECT_DIR/module/customize.sh"

require() {
    grep -Fq "$1" "$2" || {
        printf 'FAIL missing %s in %s\n' "$1" "$2" >&2
        exit 1
    }
}

reject() {
    if grep -Fq "$1" "$2"; then
        printf 'FAIL forbidden %s in %s\n' "$1" "$2" >&2
        exit 1
    fi
}

require 'open(INPUT_DEVICE, O_RDONLY | O_NONBLOCK | O_CLOEXEC)' "$SOURCE"
require 'BTN_TRIGGER_HAPPY32' "$SOURCE"
require 'CLOCK_MONOTONIC' "$SOURCE"
require 'SYN_DROPPED' "$SOURCE"
require 'input device reached EOF' "$SOURCE"
require 'partial input event read' "$SOURCE"
require '"/system/bin/service", "service", "call", "contextual_search"' "$SOURCE"
require '"2", "i32", "2"' "$SOURCE"
reject 'EVIOCGRAB' "$SOURCE"
reject 'screencap' "$SOURCE"
reject 'http://' "$SOURCE"
reject 'https://' "$SOURCE"
require '"$MODDIR/bin/contextual-sidekey"' "$SERVICE"
require 'id=contextual_sidekey' "$MODULE"
require 'PLK110_16.0.9.400(CN01)' "$CUSTOMIZE"
require 'OP60FFL1' "$CUSTOMIZE"

printf 'PASS source contract\n'
