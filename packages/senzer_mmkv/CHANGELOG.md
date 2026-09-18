## 0.1.0

- Fixed value-change listeners so subscriptions on one handle observe writes
  made through another handle for the same MMKV storage file.
- Initial DartNative community plugin backed by Tencent MMKV Core 2.4.2.
- Added synchronous typed values, buffers, multiple instances, read-only mode,
  compare-before-set, multi-process refresh, trimming, import, listeners, CRC
  recovery, AES-128/AES-256 encryption, rekey/decrypt, and memory-cache control.
- Added iOS and Android FFI/JNI packaging.
- Added exact signed 64-bit Dart integer accessors without changing the
  JavaScript-compatible double-based `set`/`getNumber` behavior.
