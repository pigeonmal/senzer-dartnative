# senzer_mmkv example

This DartNative app is the device-level regression and benchmark harness for
`senzer_mmkv`.

## Validate and benchmark

```sh
dn pub get
dn analyze
dn run --release -d <android-device-or-emulator>
```

The app runs the complete native integration suite from
`lib/integration_tests.dart`, then the eight-case benchmarks from
`lib/benchmarks/` for `senzer_mmkv`, `dartnative_hive`, and
`dartnative_shared_preferences`. Watch for `[MMKV_TEST] ALL PASS`,
`[MMKV_BENCH]`, `[HIVE_BENCH]`, and `[SHARED_PREFERENCES_BENCH]` in the native
output. Hive and Shared Preferences are comparison-only app dependencies;
they are not dependencies of the package. Shared Preferences does not expose a
binary value type, so its 256-byte buffer cases serialize the payload as
base64 text and include that conversion cost.

Use a physical iOS device for a release benchmark. DartNative currently rejects
Release/Profile AOT builds for iOS simulators, although a simulator remains
useful for non-release integration checks.

Always use `dn` for DartNative commands. The app must register
`DartNativePluginRegistrant` before the first widget; this is already wired in
`lib/main.dart`.
