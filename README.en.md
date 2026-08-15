# PLK110 Contextual Search Side Key

[简体中文](README.md) | **English**

Map the OnePlus PLK110 action key long press to Android 16 Contextual Search, which is used by Google Circle to Search. This is a small, device-specific implementation, not a fork of ETA.

## What is included

- `app/`: a libxposed compatibility module that bootstraps the framework service when needed, routes it to the Google App, and answers the Google App's device eligibility checks.
- `daemon/`: a KernelSU module containing one native process. It reads `/dev/input/event0` without `EVIOCGRAB` and invokes `service call contextual_search 2 i32 2` after an 800 ms `BTN_TRIGGER_HAPPY32` press.

No screenshot pipeline, UI, network client, Google binary, or unrelated ETA feature is included.

## Verified baseline

This project was physically verified on 2026-08-16 with:

| Component | Verified value |
| --- | --- |
| Device | OnePlus PLK110 / `OP60FFL1` |
| ROM | `PLK110_16.0.9.400(CN01)` |
| Android | 16 / API 36 |
| Root | KernelSU-Next 3.3.0 |
| Hook API | libxposed API 102 |
| Google App | `16.46.63.ve.arm64` / `301639434` |

The Google App installation also contained these official dynamic features:

- `lens_ondevice_engine_feature_module`
- `lens_ondevice_engine_play_ml_module`
- `tclib_native_feature_module`

They are not distributed by this repository. Install Google software only from a source you trust, and never mix APKs with different versions or signing certificates.

## Build

Requirements:

- JDK 21
- Android SDK 36
- Android NDK (28.2 tested)
- `zip`, `unzip`, `rg`, and a POSIX shell

Set `ANDROID_SDK_ROOT` or `ANDROID_HOME`, then run:

```sh
./build.sh
```

Artifacts are written to `dist/`:

- `contextual-search-compat-v1.2.2.apk`
- `contextual-sidekey-plk110-v1.0.0.zip`

The APK currently uses the local Android debug signing configuration. Use a private release key for redistributed production builds; never commit that key.

## Install

1. Install the compatibility APK in a libxposed API 102 compatible framework and enable its static scopes: `system` and `com.google.android.googlequicksearchbox`.
2. Reboot and verify the service: `adb shell service check contextual_search`.
3. Verify the Google App includes the required dynamic features: `adb shell pm path com.google.android.googlequicksearchbox`.
4. Test the framework route directly: `adb shell service call contextual_search 2 i32 2`.
5. Only after the overlay works, install the KernelSU ZIP and reboot.
6. Long-press the PLK110 action key for about one second.

The numeric Binder transaction and private framework hooks are not stable Android APIs. Do not install this build on another ROM or Google App version without reviewing and retesting them.

## Troubleshooting

- Service missing after reboot: confirm the compatibility module is enabled for `system`.
- Overlay stays on its enabling screen: inspect logcat for missing Google dynamic feature splits. Do not replace this with a Lens deep link.
- Side key does nothing: confirm `/dev/input/event0` exposes `BTN_TRIGGER_HAPPY32`, then inspect `/data/adb/modules/contextual_sidekey/daemon.log`.
- Duplicate process: the daemon uses a singleton lock at `/data/local/tmp/contextual-sidekey.lock`; only one instance should survive.

## Rollback

Disable or uninstall the `contextual_sidekey` KernelSU module and reboot. Disable or uninstall the compatibility module and reboot to remove its hooks. Neither action requires writing a device partition.

## License

MIT
