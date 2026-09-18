# senzer_mmkv

Synchronous, C++-backed MMKV-compatible key-value storage for DartNative.
Version `0.1.0` is developed in this repository and is **not published to
pub.dev**.

The API follows the storage and factory surface documented by
[`react-native-mmkv`](https://github.com/margelo/react-native-mmkv), adapted to
typed Dart values and FFI. It does not include React hooks, React Native mocks,
or the upstream web adapter.

Supported targets are iOS 15+ and Android API 23+. The package has no SQLite or
Hive dependency. Android ABI selection remains the host application's choice;
the plugin does not set `abiFilters`.

## Install

Use a path dependency while the package is unreleased:

```yaml
dependencies:
  senzer_mmkv:
    path: ../senzer-dartnative/packages/senzer_mmkv
```

Then run `dn pub get`. Register the generated DartNative plugins before the
first widget:

```dart
DartNativePluginRegistrant.registerAll();
```

## Quick start

```dart
import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

final storage = createMMKV(id: 'settings');
storage.set('theme', 'dark');
storage.set('launchCount', (storage.getNumber('launchCount') ?? 0) + 1);
storage.set('enabled', true);
storage.set('token', Uint8List.fromList(<int>[1, 2, 3]));
storage.setInt64('revision', 9223372036854775807);

final theme = storage.getString('theme');
final keys = storage.getAllKeys();
final revision = storage.getInt64('revision');
storage.close();
```

`set` accepts `String`, `bool`, `num`, `Uint8List`, and `List<int>`.

## API at a glance

| Need | API |
| --- | --- |
| Write/read values | `set`, `getString`, `getBoolean`, `getNumber`, `getBuffer` |
| Exact integers | `setInt64`/`getInt64` or `setInt`/`getInt` |
| Inspect data | `contains`, `getAllKeys`, `length`, `byteSize` |
| Delete data | `remove`, `clearAll`, `trim` |
| Multiple processes | `MMKVMode.multiProcess`, `checkContentChanged` |
| Memory control | `clearMemoryCache` |
| Import and listeners | `importAllFrom`, `addOnValueChangedListener` |
| Instance lifecycle | `existsMMKV`, `deleteMMKV`, `close` |
| Custom root | `initializeMMKV`, `path:` |
| Open options | `readOnly`, `compareBeforeSet`, `recoveryStrategy` |

## Encryption

For protected values, opt in explicitly to AES-128 or AES-256:

```dart
final secure = createMMKV(
  id: 'secure-settings',
  encryptionKey: 'a-32-byte-secret-key-for-aes-256',
  encryptionType: MMKVEncryptionType.aes256,
);
secure.set('refreshToken', '...');
secure.encrypt('01234567890123456789012345678901', encryptionType: MMKVEncryptionType.aes256);
secure.decrypt(); // rewrites the file as plaintext when that is intentional
```

AES-128 and AES-256 keys must be exactly 16 or 32 UTF-8 bytes. Encryption is
never silently downgraded to plaintext. `encrypt`, `decrypt`, and the
deprecated `recrypt` method rewrite the existing file synchronously. Generate
and persist keys with Keychain/Keystore or another secure store; never commit
them or derive them from public constants.

Call `initializeMMKV('/shared/app-group/mmkv')` before `createMMKV` when an
extension or app group needs an explicit shared root. The generated registrant
loads the Android plugin and iOS symbols automatically; alternatively call
`SenzerMMKVBindings.loadSymbols()` once before creating an instance.

## Android benchmark

The checked-in example app measures the eight storage cases used for the React
Native comparison: string, number, boolean, and 256-byte buffer writes and
reads. Each case performs 1,000 operations, with two warm-up rounds and seven
measured rounds; the table reports the median. Measurements are unencrypted and
were taken in release mode on an **Android Xiaomi Pad 6** (Android 14,
`arm64-v8a`).

<p align="center">
  <img src="../../docs/benchmarks/benchmark_xiaomi_pad_6.svg" alt="Android Xiaomi Pad 6 Storage Benchmark Chart" width="100%" />
</p>

The complete workload definition, all 8 measured operations, and reproduction notes are in
[`docs/benchmarks/android-xiaomi-pad-6.md`](../../docs/benchmarks/android-xiaomi-pad-6.md).
Hive and SQLite are comparison-only dependencies of the example app. The React
Native rows are a previously recorded baseline from a fresh React Native
`0.87.1` TypeScript app with `react-native-mmkv` `4.3.2`; they were not rerun
during the final DartNative hot-path optimization.

## Example and validation

The checked-in [`example/`](example) app keeps the integration suite and the
benchmark cases in separate files. It covers typed round trips, wrong-type
probes, listeners, import, encryption, read-only mode, maintenance calls,
instance deletion, and lifecycle guards.

```sh
cd example
dn pub get
dn analyze
dn run --release -d <android-device-or-emulator>
```

Use a physical iOS device for release benchmarking. DartNative's current iOS
AOT builder intentionally rejects Release/Profile simulator builds; a
simulator can still be used for non-release integration checks.

## Native design

- The package links Tencent MMKV Core 2.4.2, the mmap-backed C++ engine used by
  the upstream React Native package.
- Dart calls cross a small pointer-plus-length FFI ABI. Reusable per-instance
  scratch buffers keep hot reads and writes allocation-light.
- The Dart wrapper does not maintain a second key/value cache; MMKV remains the
  source of truth.
- `trim()` compacts the file. `clearMemoryCache()` drops native cached values so
  the next read can reload from disk after a memory warning.
- Android uses a small plugin lifecycle adapter to load the native library and
  establish the app sandbox path; no method channel is used. iOS resolves the
  Library sandbox path in Objective-C++ and exposes the same ABI through
  `DynamicLibrary.process()`.

## Storage location

By default, iOS uses `<Application Library>/mmkv` and Android uses
`<Application filesDir>/mmkv`. Pass `path:` to `MMKV` or `createMMKV` to select
a different app-owned directory. Instance IDs are filename-safe values and are
encoded by MMKV when needed for safe filesystem storage.

## License and notices

The DartNative wrapper is MIT-licensed. Native storage is provided by
[Tencent MMKV Core 2.4.2](https://github.com/Tencent/MMKV), licensed under the
BSD 3-Clause license; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
The package contains no Senzer product code, credentials, endpoints, or private
assets.
