# senzer_mmkv simulator benchmark baseline

This is the initial regression baseline for the `senzer_mmkv` package. It
records the package at `HEAD` before the uncommitted Dart/C++ hardening changes.
Before/after comparisons are reported separately in the task conversation.

## Environment

- Host: Apple M5 (`Mac17,3`)
- iOS simulator: `DartNative iPhone`, iOS `26.5`
- Android emulator: `Android SDK built for arm64`, Android `12`, `arm64-v8a`
- Build mode: Debug simulator/emulator (DartNative does not support iOS
  simulator Release/Profile AOT builds)
- Storage: unencrypted MMKV
- Benchmark operations: 1,000 per case
- Warm-up rounds: 2
- Measured rounds: 7; reported value is the median measured round

The benchmark timer covers only each storage operation loop. App startup,
integration checks, and the adversarial suite are outside the timed region.

## Initial baseline — `HEAD` without the changes

### iOS simulator

| Case | Median elapsed | Ops/s |
| --- | ---: | ---: |
| String write | 0.208 ms | 4,807,692 |
| String read | 0.377 ms | 2,652,520 |
| Number write | 0.113 ms | 8,849,558 |
| Number read | 0.071 ms | 14,084,507 |
| Boolean write | 0.137 ms | 7,299,270 |
| Boolean read | 0.069 ms | 14,492,754 |
| Buffer write 256 B | 0.263 ms | 3,802,281 |
| Buffer read 256 B | 0.195 ms | 5,128,205 |

The baseline app completed 26 integration checks.

### Android emulator

| Case | Median elapsed | Ops/s |
| --- | ---: | ---: |
| String write | 3.989 ms | 250,689 |
| String read | 3.883 ms | 257,533 |
| Number write | 1.643 ms | 608,643 |
| Number read | 0.472 ms | 2,118,644 |
| Boolean write | 1.695 ms | 589,971 |
| Boolean read | 0.437 ms | 2,288,330 |
| Buffer write 256 B | 2.589 ms | 386,250 |
| Buffer read 256 B | 1.959 ms | 510,465 |
