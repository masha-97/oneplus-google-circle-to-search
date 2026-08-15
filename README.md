# 一加手机实现谷歌一圈即搜

**简体中文** | [English](README.en.md)

将一加 PLK110 智能侧键的长按动作映射到 Android 16 Contextual Search，从而唤起 Google 原生圈选即搜。

## 包含内容

- `app/`：libxposed 兼容模块。必要时补齐 Contextual Search 框架服务，将服务目标指定为 Google App，并处理 Google App 的设备资格检查。
- `daemon/`：仅包含一个原生进程的 KernelSU 模块。它以非独占方式读取 `/dev/input/event0`，检测 `BTN_TRIGGER_HAPPY32` 长按 800 毫秒后执行 `service call contextual_search 2 i32 2`。

## 已验证环境

本项目已于 2026-08-16 在以下环境完成真机验证：

| 项目 | 已验证版本 |
| --- | --- |
| 设备 | OnePlus PLK110 / `OP60FFL1` |
| 系统 | `PLK110_16.0.9.400(CN01)` |
| Android | 16 / API 36 |
| Root | KernelSU-Next 3.3.0 |
| Hook API | libxposed API 102 |
| Google App | `16.46.63.ve.arm64` / `301639434` |

Google App 还需包含以下官方动态功能模块：

- `lens_ondevice_engine_feature_module`
- `lens_ondevice_engine_play_ml_module`
- `tclib_native_feature_module`

本仓库不分发这些模块。请只从可信来源安装 Google 软件，且不要混装版本号或签名证书不同的 APK。

## 构建

依赖：

- JDK 21
- Android SDK 36
- Android NDK（已验证 28.2）
- `zip`、`unzip`、`rg` 和 POSIX Shell

设置 `ANDROID_SDK_ROOT` 或 `ANDROID_HOME` 后执行：

```sh
./build.sh
```

构建产物位于 `dist/`：

- `contextual-search-compat-v1.2.2.apk`
- `contextual-sidekey-plk110-v1.0.0.zip`


## 安装

1. 在兼容 libxposed API 102 的框架中安装兼容模块 APK，并启用静态作用域：`system` 和 `com.google.android.googlequicksearchbox`。
2. 重启后检查服务：`adb shell service check contextual_search`。
3. 检查 Google App 是否包含所需动态功能模块：`adb shell pm path com.google.android.googlequicksearchbox`。
4. 直接验证框架调用：`adb shell service call contextual_search 2 i32 2`。
5. 确认原生覆盖层能够正常打开后，再安装 KernelSU ZIP 并重启。
6. 长按智能侧键约一秒。


## 故障排查

- 重启后服务不存在：确认兼容模块已对 `system` 启用。
- 覆盖层停在“正在启用”：检查 logcat 是否提示缺少 Google 动态功能模块，不要用 Lens 深链替代。
- 侧键没有反应：确认 `/dev/input/event0` 提供 `BTN_TRIGGER_HAPPY32`，然后检查 `/data/adb/modules/contextual_sidekey/daemon.log`。
- 出现重复进程：守护进程通过 `/data/local/tmp/contextual-sidekey.lock` 保证单实例，正常情况下只应保留一个进程。

## 回退

禁用或卸载 `contextual_sidekey` KernelSU 模块并重启；再禁用或卸载兼容模块并重启，即可移除所有 Hook。整个过程不需要写入设备分区。

## 许可证

MIT
