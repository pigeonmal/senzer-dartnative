# Android MMKV dependency

Android intentionally uses `io.github.zhongwuzw:mmkv:2.4.2`, a fork/repack of
Tencent MMKV 2.4.2 maintained at <https://github.com/zhongwuzw/MMKV>. It is not
a migration to a different MMKV engine: the CocoaPod uses Tencent MMKV Core
2.4.2, and the fork's Prefab module plus `MMKV.h`, `MMBuffer.h`, and
`MMKVPredef.h` match Tencent's 2.4.2 API. The fork is retained because its AAR
includes `armeabi-v7a`; Tencent's published 2.4.2 Android AAR contains only
`arm64-v8a` and `x86_64`.

The checked-in `verifyMmkvForkAbis` Gradle task verifies that the resolved
fork AAR contains `libmmkv.so` and `libc++_shared.so` for all four supported
ABIs: `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64`. It also checks that the
Prefab module and public headers are present, and is wired into Gradle's
`check` lifecycle. The plugin does not impose `abiFilters` on consuming apps.

When upgrading the Android MMKV version:

1. Confirm the fork's release/tag and source commit, and identify the exact
   matching Tencent MMKV tag; do not compare against `master`.
2. Compare the fork AAR's Prefab module metadata and `MMKV.h`, `MMBuffer.h`,
   and `MMKVPredef.h` against Tencent's AAR for that exact release. Investigate
   any API, layout, compile-definition, or calling-convention difference
   before accepting the fork update.
3. Run `gradle -p packages/senzer_mmkv/android verifyMmkvForkAbis` and verify
   that all four ABI libraries remain present. This task is also wired into the
   plugin's Gradle `check` lifecycle. If ABI support changes intentionally,
   update both the build guard and this support statement.
4. Build/run the package's Android example integration/security suite on an Android
   device or emulator. It exercises native read/write round-trips, integer
   boundaries, deletion with concurrent handles, and reopening after stale
   handles close.
