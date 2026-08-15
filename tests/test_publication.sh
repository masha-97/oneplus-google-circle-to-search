#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FORBIDDEN_PATTERN='/''Users/|live-plk110-''profile'

if find "$PROJECT_DIR" \
    -path "$PROJECT_DIR/.git" -prune -o \
    -path "$PROJECT_DIR/.gradle" -prune -o \
    -path '*/build' -prune -o \
    -path "$PROJECT_DIR/dist" -prune -o \
    -type f \( -name '*.apk' -o -name '*.apkm' -o -name '*.zip' \
        -o -name '*.png' -o -name 'local.properties' \) -print \
    | grep -q .; then
    echo "Forbidden generated or device artifact in publication source" >&2
    exit 1
fi

if rg -n --hidden \
    -g '!/.git/**' -g '!/.gradle/**' -g '!**/build/**' -g '!dist/**' \
    "$FORBIDDEN_PATTERN" "$PROJECT_DIR"; then
    echo "Local path or device identifier found in publication source" >&2
    exit 1
fi

echo "Publication hygiene: PASS"
