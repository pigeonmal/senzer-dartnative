# React Native MMKV — iOS Simulator benchmark

Baseline measurement for `react-native-mmkv` on an Apple Silicon M5 host.

## Environment

- React Native `0.87.1`
- `react-native-mmkv` `4.3.2`
- `react-native-nitro-modules` `0.37.1`
- iOS Simulator: `DartNative iPhone`, iOS `26.5`
- Configuration: **Release**, arm64 simulator binary
- Storage: unencrypted MMKV

The app was built with Xcode and installed with `simctl`; no Metro server was
used for the measured run.

## Method

Each case performs 1,000 operations. The harness runs two warm-up rounds and
seven measured rounds, then reports the median measured round. Elapsed time is
for the operation loop only; throughput is calculated as `1,000 / elapsed`.

## Results

| Case | Median elapsed for 1,000 operations | Median ops/s |
| --- | ---: | ---: |
| String write | 0.204 ms | 4,912,990.893 |
| String read | 0.171 ms | 5,855,075.230 |
| Number write | 0.177 ms | 5,661,712.479 |
| Number read | 0.112 ms | 8,941,904.551 |
| Boolean write | 0.170 ms | 5,892,474.179 |
| Boolean read | 0.108 ms | 9,277,126.533 |
| Buffer write 256 B | 0.271 ms | 3,688,335.588 |
| Buffer read 256 B | 0.289 ms | 3,454,231.456 |

## Runtime validation

The same Release arm64 app completed **26/26 integration checks**, covering
typed round trips, wrong-type reads, key enumeration, size accounting,
listeners, removal, maintenance, import, AES-128/AES-256 encryption,
decrypt/recrypt, read-only mode, multi-process/recovery options, constructor
encryption, clearing, and instance deletion.

This document records the React Native baseline only; it is not a
`senzer_mmkv` measurement.
