#!/bin/sh
set -eu

APK_NAME=contextual-search-compat-v1.2.2.apk
MODULE_NAME=contextual-sidekey-plk110-v1.0.0.zip
SUMS_NAME=SHA256SUMS
GOOGLE_PACKAGE=com.google.android.googlequicksearchbox

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

usage() {
    cat <<'EOF'
Usage:
  ./tools/plk110-assistant.sh check
  ./tools/plk110-assistant.sh install <directory>
  ./tools/plk110-assistant.sh verify

check   Read-only verification of the connected PLK110 and required Google features.
install Install the compatibility APK and copy the KernelSU ZIP to Download/. It never
        enables Xposed scopes or installs a KernelSU module without the manager UI.
verify  Read-only post-reboot checks after the two manager-side install steps.
EOF
}

require_adb() {
    ADB=$(command -v adb || true)
    [ -n "$ADB" ] || die 'adb is required. Install Android platform-tools first.'
    DEVICE_COUNT=$($ADB devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')
    [ "$DEVICE_COUNT" = 1 ] || die "connect exactly one authorized Android device (found $DEVICE_COUNT)."
}

adb_shell() { "$ADB" shell "$@"; }
prop() { adb_shell getprop "$1" | tr -d '\r'; }

require_value() {
    actual=$(prop "$1")
    [ "$actual" = "$2" ] || die "$3: expected $2, got ${actual:-empty}."
    info "PASS $3: $actual"
}

require_google_features() {
    paths=$(adb_shell pm path "$GOOGLE_PACKAGE" 2>/dev/null || true)
    [ -n "$paths" ] || die 'Google App is not installed.'
    for feature in lens_ondevice_engine_feature_module lens_ondevice_engine_play_ml_module tclib_native_feature_module; do
        case "$paths" in
            *"$feature"*) info "PASS Google feature: $feature" ;;
            *) die "Google feature is missing: $feature. Install matching official Google App splits first." ;;
        esac
    done
}

check_device() {
    require_adb
    require_value ro.product.model PLK110 'model'
    require_value ro.product.device OP60FFL1 'device'
    require_value ro.build.version.sdk 36 'Android SDK'
    require_value ro.product.cpu.abi arm64-v8a 'ABI'
    require_value ro.build.display.id 'PLK110_16.0.9.400(CN01)' 'ColorOS build'

    root_identity=$(adb_shell su -c id 2>/dev/null || true)
    case "$root_identity" in
        uid=0\(root\)*) info 'PASS root shell' ;;
        *) die 'KernelSU root shell is unavailable. Grant root to ADB and try again.' ;;
    esac
    ksu_version=$(adb_shell su -c 'ksud -V' 2>/dev/null || true)
    case "$ksu_version" in
        ksud*) info "PASS $ksu_version" ;;
        *) die 'KernelSU daemon was not found. This project does not support another root manager.' ;;
    esac
    require_google_features
}

verify_assets() {
    ASSET_DIR=$1
    [ -f "$ASSET_DIR/$APK_NAME" ] || die "missing $APK_NAME"
    [ -f "$ASSET_DIR/$MODULE_NAME" ] || die "missing $MODULE_NAME"
    [ -f "$ASSET_DIR/$SUMS_NAME" ] || die "missing $SUMS_NAME"
    for asset in "$APK_NAME" "$MODULE_NAME"; do
        expected=$(awk -v name="$asset" '$NF == name { print $1 }' "$ASSET_DIR/$SUMS_NAME")
        [ -n "$expected" ] || die "$SUMS_NAME has no hash for $asset"
        actual=$(shasum -a 256 "$ASSET_DIR/$asset" | awk '{print $1}')
        [ "$actual" = "$expected" ] || die "SHA-256 mismatch for $asset"
        info "PASS SHA-256: $asset"
    done
}

install_release() {
    ASSET_DIR=$1
    check_device
    verify_assets "$ASSET_DIR"
    info ''
    info 'This installs only the compatibility APK and copies the KernelSU ZIP to Download/.'
    info 'You must still enable the two Xposed scopes, reboot, then import the ZIP in KernelSU Manager.'
    printf 'Type INSTALL to continue: '
    read -r answer
    [ "$answer" = INSTALL ] || die 'installation cancelled.'
    "$ADB" install -r "$ASSET_DIR/$APK_NAME"
    "$ADB" push "$ASSET_DIR/$MODULE_NAME" "/sdcard/Download/$MODULE_NAME"
    info ''
    info 'NEXT 1/3: In the Xposed manager, enable static scopes: system and com.google.android.googlequicksearchbox.'
    info 'NEXT 2/3: Reboot and run: ./tools/plk110-assistant.sh verify'
    info "NEXT 3/3: Import Download/$MODULE_NAME in KernelSU Manager, reboot, then long-press the action key."
}

verify_install() {
    check_device
    service=$(adb_shell service check contextual_search 2>/dev/null || true)
    case "$service" in
        *'found'*) info "PASS $service" ;;
        *) die 'contextual_search service is missing. Check that the Xposed module is enabled for system, then reboot.' ;;
    esac
    module=$(adb_shell su -c 'test -d /data/adb/modules/contextual_sidekey && echo installed' 2>/dev/null || true)
    [ "$module" = installed ] || die 'contextual_sidekey is not installed. Import the prepared ZIP in KernelSU Manager, then reboot.'
    info 'PASS KernelSU side-key module is installed'
    info 'Ready: long-press the PLK110 action key for about one second.'
}

[ $# -ge 1 ] || { usage; exit 1; }
case "$1" in
    check) [ $# = 1 ] || die 'check takes no arguments'; check_device ;;
    install) [ $# = 2 ] || die 'install needs <directory>'; install_release "$2" ;;
    verify) [ $# = 1 ] || die 'verify takes no arguments'; verify_install ;;
    *) usage; exit 1 ;;
esac
