# Android Xiaomi Pad 6 storage benchmark

Benchmark run: 2026-09-18 on an Android Xiaomi Pad 6 (`arm64-v8a`, Android
14). All Android builds were release builds and the workload executed 1,000
operations per case. Each case used two warm-up rounds followed by seven
measured rounds; the table reports the median measured round.

The TypeScript React Native comparison was run from a fresh React Native
`0.87.1` blank app with `react-native-mmkv` `4.3.2` and
`react-native-nitro-modules` `0.37.1`. The DartNative comparison used
`senzer_mmkv` `0.1.0`, `dartnative_sqlite` `1.0.0`, and
`dartnative_hive` `1.0.0`.

The optimized `senzer_mmkv` rows below were rerun after the C++/FFI hot-path
changes. Its harness clears and seeds the MMKV instance before each measured
round, matching the React Native runner's per-round setup. The React Native
rows are the previously recorded baseline and were intentionally not rerun.
The senzer harness also uses the same string and 256-byte payloads, per-round
keys, varying number writes, and alternating boolean writes as the RN cases.

SQLite and Hive are used only by the checked-in comparison benchmarks in the
example app; they are not dependencies of the public `senzer_mmkv` package.

The cases are intentionally small storage calls: string, number, boolean, and
a 256-byte buffer, each written and read. SQLite and Hive use
their package APIs, so their rows include the overhead of those APIs and are
not a claim that their underlying databases are equivalent to MMKV. The
measurements are unencrypted; encryption is a separate workload because the
comparison libraries do not expose the same encryption contract.

| Store | Case | Median elapsed for 1,000 ops (ms) | Median ops/s |
| --- | --- | ---: | ---: |
| `senzer_mmkv` | string write | 0.808 | 1,237,623.762 |
| `senzer_mmkv` | string read | 0.259 | 3,861,003.861 |
| `senzer_mmkv` | number write | 0.770 | 1,298,701.299 |
| `senzer_mmkv` | number read | 0.164 | 6,097,560.976 |
| `senzer_mmkv` | boolean write | 0.761 | 1,314,060.447 |
| `senzer_mmkv` | boolean read | 0.119 | 8,403,361.345 |
| `senzer_mmkv` | buffer write 256B | 0.817 | 1,223,990.208 |
| `senzer_mmkv` | buffer read 256B | 0.248 | 4,032,258.065 |
| `dartnative_hive` | string write | 87.049 | 11,487.783 |
| `dartnative_hive` | string read | 0.191 | 5,235,602.094 |
| `dartnative_hive` | number write | 66.011 | 15,148.990 |
| `dartnative_hive` | number read | 0.328 | 3,048,780.488 |
| `dartnative_hive` | boolean write | 82.145 | 12,173.595 |
| `dartnative_hive` | boolean read | 0.245 | 4,081,632.653 |
| `dartnative_hive` | buffer write 256B | 75.030 | 13,328.002 |
| `dartnative_hive` | buffer read 256B | 0.256 | 3,906,250.000 |
| `dartnative_sqlite` | string write | 135.801 | 7,363.717 |
| `dartnative_sqlite` | string read | 174.818 | 5,720.235 |
| `dartnative_sqlite` | number write | 141.217 | 7,081.300 |
| `dartnative_sqlite` | number read | 150.811 | 6,630.817 |
| `dartnative_sqlite` | boolean write | 122.729 | 8,148.033 |
| `dartnative_sqlite` | boolean read | 128.047 | 7,809.632 |
| `dartnative_sqlite` | buffer write 256B | 129.423 | 7,726.602 |
| `dartnative_sqlite` | buffer read 256B | 130.491 | 7,663.364 |
| `react-native-mmkv` | string write | 1.637 | 610,920.186 |
| `react-native-mmkv` | string read | 0.639 | 1,564,284.389 |
| `react-native-mmkv` | number write | 1.464 | 683,274.318 |
| `react-native-mmkv` | number read | 0.429 | 2,331,230.894 |
| `react-native-mmkv` | boolean write | 1.662 | 601,842.949 |
| `react-native-mmkv` | boolean read | 0.313 | 3,198,402.897 |
| `react-native-mmkv` | buffer write 256B | 2.262 | 442,009.459 |
| `react-native-mmkv` | buffer read 256B | 1.325 | 754,657.749 |

## Reproduction

The React Native run launched the release APK over ADB. Its APK contained only
`arm64-v8a` native libraries. The DartNative example app ran the
`senzer_mmkv`, `dartnative_hive`, and `dartnative_sqlite` comparison cases on
the same device using a release `android-arm64` split APK. Device serials are
intentionally omitted from this public repository.
