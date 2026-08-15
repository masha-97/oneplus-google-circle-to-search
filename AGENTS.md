# Project Rules

This repository intentionally contains only two runtime components:

1. A libxposed compatibility module for Android Contextual Search.
2. A non-exclusive evdev daemon for the PLK110 action key.

Hard boundaries:

- Do not add UI, screenshots, networking, configuration pages, analytics, or ETA features.
- Do not use `google://lens`, `VOICE_ASSIST`, or Google App activities as substitutes.
- The daemon must only read `/dev/input/event0`, watch `BTN_TRIGGER_HAPPY32`, and invoke the verified Contextual Search Binder command after a long press.
- Never add `EVIOCGRAB`; the action key must remain non-exclusive.
- Preserve recovery for `SYN_DROPPED`, EOF, partial events, and device reconnects.
- Do not commit Google APKs, dynamic feature splits, device captures, serial numbers, local paths, signing keys, or build outputs.
- Keep the default Chinese `README.md` and English `README.en.md` synchronized in the same commit.
- Treat Binder transaction IDs and private framework method names as version-specific.
- Keep the strict PLK110 model, device, SDK, ABI, and build gates in the KernelSU installer.

Before release, run `./build.sh` and inspect `git diff --check` plus `git status --short`.
