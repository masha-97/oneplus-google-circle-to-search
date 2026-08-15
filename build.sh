#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DIST_DIR="$PROJECT_DIR/dist"

"$PROJECT_DIR/gradlew" --no-daemon clean :app:assembleRelease :app:lintRelease
"$PROJECT_DIR/tests/test_compat_contract.sh"
"$PROJECT_DIR/tests/test_publication.sh"
"$PROJECT_DIR/tests/test_installer_contract.sh"

mkdir -p "$DIST_DIR"
cp "$PROJECT_DIR/app/build/outputs/apk/release/app-release.apk" \
    "$DIST_DIR/contextual-search-compat-v1.2.2.apk"
DIST_DIR="$DIST_DIR" "$PROJECT_DIR/daemon/build.sh"

shasum -a 256 \
    "$DIST_DIR/contextual-search-compat-v1.2.2.apk" \
    "$DIST_DIR/contextual-sidekey-plk110-v1.0.0.zip"
