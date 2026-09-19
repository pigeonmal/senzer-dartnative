# Android Xiaomi Pad 6 storage benchmark

Benchmark run: 2026-09-19 on an Android Xiaomi Pad 6 (`arm64-v8a`, Android
14). All Android builds were release builds and the workload executed 1,000
operations per case. Each case used two warm-up rounds followed by seven
measured rounds. DartNative values are the arithmetic mean of the per-case
medians from two independent app launches.

The TypeScript React Native comparison was run from a fresh React Native
`0.87.1` blank app with `react-native-mmkv` `4.3.2` and
`react-native-nitro-modules` `0.37.1`. The DartNative comparison used
`senzer_mmkv` `0.1.0`, `dartnative_hive` `1.0.0`, and
`dartnative_shared_preferences` `1.0.1`.

The optimized `senzer_mmkv` rows below were rerun after the C++/FFI hot-path
changes. Its harness clears and seeds the MMKV instance before each measured
round, matching the React Native runner's per-round setup. The React Native
rows are the previously recorded baseline and were intentionally not rerun.
The senzer harness also uses the same string and 256-byte payloads, per-round
keys, varying number writes, and alternating boolean writes as the RN cases.

Hive and Shared Preferences are used only by the checked-in comparison
benchmarks in the example app; they are not dependencies of the public
`senzer_mmkv` package. The third-party `mmkv` package on pub.dev was not added:
it targets Flutter and depends on Flutter bindings, so it is not a compatible
DartNative comparison without a DN port.

The cases are intentionally small storage calls: string, number, boolean, and
a 256-byte buffer, each written and read. Hive and Shared Preferences use
their package APIs, so their rows include the overhead of those APIs and are
not a claim that their underlying storage engines are equivalent to MMKV.
Shared Preferences has no binary value type, so its buffer rows base64-encode
and decode the same 256-byte payload as a string; those rows include the
conversion cost. The measurements are unencrypted; encryption is a separate
workload because the comparison libraries do not expose the same encryption
contract.

| Store | Case | Elapsed for 1,000 ops (ms) | Ops/s |
| --- | --- | ---: | ---: |
| `senzer_mmkv` | string write | 0.821 | 1,218,026.797 |
| `senzer_mmkv` | string read | 0.245 | 4,081,632.653 |
| `senzer_mmkv` | number write | 0.772 | 1,296,176.280 |
| `senzer_mmkv` | number read | 0.143 | 6,968,641.115 |
| `senzer_mmkv` | boolean write | 0.766 | 1,305,483.029 |
| `senzer_mmkv` | boolean read | 0.126 | 7,968,127.490 |
| `senzer_mmkv` | buffer write 256B | 0.817 | 1,224,739.743 |
| `senzer_mmkv` | buffer read 256B | 0.226 | 4,424,778.761 |
| `dartnative_hive` | string write | 126.343 | 7,914.993 |
| `dartnative_hive` | string read | 0.120 | 8,298,755.187 |
| `dartnative_hive` | number write | 94.756 | 10,553.477 |
| `dartnative_hive` | number read | 0.186 | 5,361,930.295 |
| `dartnative_hive` | boolean write | 94.834 | 10,544.797 |
| `dartnative_hive` | boolean read | 0.217 | 4,597,701.149 |
| `dartnative_hive` | buffer write 256B | 107.237 | 9,325.140 |
| `dartnative_hive` | buffer read 256B | 0.209 | 4,796,163.070 |
| `dartnative_shared_preferences` | string write | 25.726 | 38,871.181 |
| `dartnative_shared_preferences` | string read | 1.124 | 889,284.126 |
| `dartnative_shared_preferences` | number write | 22.594 | 44,259.538 |
| `dartnative_shared_preferences` | number read | 1.111 | 900,495.272 |
| `dartnative_shared_preferences` | boolean write | 20.802 | 48,072.301 |
| `dartnative_shared_preferences` | boolean read | 1.075 | 930,665.426 |
| `dartnative_shared_preferences` | buffer write 256B (base64 String) | 24.790 | 40,338.846 |
| `dartnative_shared_preferences` | buffer read 256B (base64 String) | 2.761 | 362,187.613 |
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
`senzer_mmkv`, `dartnative_hive`, and `dartnative_shared_preferences`
comparison cases on the same device using a release `android-arm64` APK. The
example's Android minimum SDK is 26, as required by the Shared Preferences
plugin. Both final runs completed the on-device test suite (`ALL PASS 201 checks`).
Device serials are intentionally omitted from this public repository.
