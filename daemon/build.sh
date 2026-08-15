#!/bin/sh
set -eu

DAEMON_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$DAEMON_DIR/.." && pwd)
BUILD_DIR="$DAEMON_DIR/build"
DIST_DIR=${DIST_DIR:-"$PROJECT_DIR/dist"}
NDK_ROOT=${ANDROID_NDK_ROOT:-}

if [ -z "$NDK_ROOT" ]; then
    SDK_ROOT=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}
    [ -n "$SDK_ROOT" ] || {
        echo "Set ANDROID_NDK_ROOT, ANDROID_SDK_ROOT, or ANDROID_HOME" >&2
        exit 1
    }
    NDK_ROOT=$(find "$SDK_ROOT/ndk" -mindepth 1 -maxdepth 1 -type d \
        | sort -V | tail -n 1)
fi

case "$(uname -s)" in
    Darwin) HOST_TAG=darwin-x86_64 ;;
    Linux) HOST_TAG=linux-x86_64 ;;
    *) echo "Unsupported build host: $(uname -s)" >&2; exit 1 ;;
esac

TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin"
CLANG="$TOOLCHAIN/aarch64-linux-android28-clang"
STRIP="$TOOLCHAIN/llvm-strip"
STAGE_DIR="$BUILD_DIR/contextual_sidekey"
OUTPUT="$DIST_DIR/contextual-sidekey-plk110-v1.0.0.zip"

[ -x "$CLANG" ] || {
    echo "Android NDK toolchain not found: $CLANG" >&2
    exit 1
}

mkdir -p "$BUILD_DIR" "$DIST_DIR"
find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p "$STAGE_DIR/bin"
cp -R "$DAEMON_DIR/module/." "$STAGE_DIR/"

"$CLANG" -std=c17 -Os -fPIE -pie -Wall -Wextra -Werror \
    "$DAEMON_DIR/src/contextual_sidekey.c" \
    -o "$STAGE_DIR/bin/contextual-sidekey"
"$STRIP" --strip-unneeded "$STAGE_DIR/bin/contextual-sidekey"
chmod 0755 "$STAGE_DIR/bin/contextual-sidekey" "$STAGE_DIR"/*.sh

"$DAEMON_DIR/tests/test_contract.sh"
for script in "$STAGE_DIR"/*.sh; do
    sh -n "$script"
done

(cd "$STAGE_DIR" && /usr/bin/zip -X -q -r "$OUTPUT.tmp" .)
mv "$OUTPUT.tmp" "$OUTPUT"
unzip -t "$OUTPUT"
