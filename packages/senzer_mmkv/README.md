# senzer_mmkv

Synchronous, native C++ key-value storage for DartNative. The public API is a
typed Dart adaptation of the current `react-native-mmkv` storage surface:
strings, booleans, numbers, byte buffers, multiple instances, read-only mode,
compare-before-set, multi-process refresh, import, trimming, deletion,
encryption/rekeying, CRC recovery, memory-cache control, and value-change
listeners.

The compatibility target is the public API documented by
[`react-native-mmkv`](https://github.com/margelo/react-native-mmkv); this
package does not bundle or copy its native sources.

Compatibility covers the native MMKV storage and factory surface. React-only
hooks, React Native mocks, and the upstream web adapter are intentionally not
included because DartNative uses Dart APIs and native FFI instead.

Supported native targets are iOS 15+ and Android API 23+.

```dart
import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

final storage = createMMKV(id: 'settings');
storage.set('theme', 'dark');
storage.set('launchCount', (storage.getNumber('launchCount') ?? 0) + 1);
storage.set('enabled', true);
storage.set('token', Uint8List.fromList(<int>[1, 2, 3]));

final theme = storage.getString('theme');
final keys = storage.getAllKeys();
storage.close();
```

For protected values, opt in explicitly to AES-128 or AES-256:

```dart
final secure = createMMKV(
  id: 'secure-settings',
  encryptionKey: 'a-32-byte-secret-key-for-aes-256',
  encryptionType: MMKVEncryptionType.aes256,
);
secure.set('refreshToken', '...');
secure.encrypt('new-32-byte-secret-key-aes-256', encryptionType: MMKVEncryptionType.aes256);
secure.decrypt(); // rewrites the file as plaintext when that is intentional
```

Call `initializeMMKV('/shared/app-group/mmkv')` before `createMMKV` when an
extension or app-group needs to select a shared default root explicitly.

Call `DartNativePluginRegistrant.registerAll()` before the first widget, or
call `SenzerMMKVBindings.loadSymbols()` once before creating an instance. The
generated registrant loads the Android plugin class and the iOS symbols
automatically.

## Native design

- The package links Tencent MMKV Core 2.4.2, the same mmap-backed C++ engine used
  by the upstream React Native package. It provides append-only protobuf storage,
  checksums, synchronous mmap writes, process locks, and lazy value caches.
- `trim()` compacts the MMKV file and clears its native memory cache. Use
  `clearMemoryCache()` after a memory warning when the next read can afford a
  reload from disk.
- AES-128 and AES-256 encryption are available at construction time and through
  `encrypt`, `decrypt`, and `recrypt`. Keys are limited to 16 or 32 UTF-8 bytes;
  encryption is never silently downgraded to plaintext.
- Encryption-key lifecycle is caller-owned: generate and persist keys with a
  platform secure store (Keychain/Keystore) rather than committing them or
  deriving them from public app constants.
- Android uses a small `FlutterPlugin` lifecycle adapter only to load the `.so`
  and establish the application sandbox path; no method channel is used.
- iOS resolves the app Library sandbox path in Objective-C++ and exposes the
  same C ABI through `DynamicLibrary.process()`.
- Keys and values cross the ABI as pointer-plus-length buffers with explicit
  `DNMMKVFree` ownership for native results.

## Storage location

By default, iOS uses `<Application Library>/mmkv` and Android uses
`<Application filesDir>/mmkv`. Pass `path:` to `MMKV` or `createMMKV` to select
a different app-owned directory. Instance IDs are filename-safe values and are
encoded by MMKV when needed for safe filesystem storage.

## Upstream and third-party notices

The DartNative wrapper is MIT-licensed. Native storage is provided by
[Tencent MMKV Core 2.4.2](https://github.com/Tencent/MMKV), which is licensed
under the BSD 3-Clause license; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

MIT. The package contains no Senzer product code, credentials, endpoints, or
private assets.
