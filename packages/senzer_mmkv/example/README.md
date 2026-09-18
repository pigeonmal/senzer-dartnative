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
`lib/benchmarks/` for `senzer_mmkv`, `dartnative_hive`, and `dartnative_sqlite`.
Watch for `[MMKV_TEST] ALL PASS`, `[MMKV_BENCH]`, `[HIVE_BENCH]`, and
`[SQLITE_BENCH]` in the native output. Hive and SQLite are comparison-only app
dependencies; they are not dependencies of the package.

Use a physical iOS device for a release benchmark. DartNative currently rejects
Release/Profile AOT builds for iOS simulators, although a simulator remains
useful for non-release integration checks.

Always use `dn` for DartNative commands. The app must register
`DartNativePluginRegistrant` before the first widget; this is already wired in
`lib/main.dart`.
