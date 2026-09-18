import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'src/listener_registry.dart';
import 'src/mmkv_bindings.dart';
import 'src/native_scratch.dart';

export 'src/mmkv_bindings.dart' show SenzerMMKVBindings;

/// Storage mode used by MMKV instances.
enum MMKVMode { singleProcess, multiProcess }

/// Encryption algorithm names accepted by the MMKV-compatible API.
enum MMKVEncryptionType { aes128, aes256 }

/// Recovery policy for CRC or file-length errors.
enum MMKVRecoveryStrategy { discardOnError, recoverOnError }

const _bufferTooSmall = -4;

/// An actionable error returned by the native MMKV core.
final class MMKVException implements Exception {
  const MMKVException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => code == null
      ? 'MMKVException: $message'
      : 'MMKVException($code): $message';
}

/// A removable value-change subscription.
final class MMKVListener {
  MMKVListener(this._remove);

  final void Function() _remove;
  bool _isRemoved = false;

  void remove() {
    if (_isRemoved) return;
    _isRemoved = true;
    _remove();
  }
}

/// Synchronous, native C++ key-value storage for DartNative.
///
/// The file format and hot path live in C++ and are shared by iOS and Android.
/// Values are persisted synchronously before [set] returns. The public surface
/// mirrors the current `react-native-mmkv` API while using Dart-native types.
final class MMKV implements Finalizable {
  MMKV({
    this.id = 'mmkv.default',
    String? path,
    String? encryptionKey,
    this.encryptionType = MMKVEncryptionType.aes128,
    this.mode = MMKVMode.singleProcess,
    this.readOnly = false,
    this.compareBeforeSet = false,
    this.recoveryStrategy,
  }) : path = path,
       _listenerScope = MMKVListenerRegistry.scopeFor(id: id, path: path),
       _handle = _open(
         id: id,
         path: path,
         encryptionKey: encryptionKey,
         encryptionType: encryptionType,
         mode: mode,
         readOnly: readOnly,
         compareBeforeSet: compareBeforeSet,
         recoveryStrategy: recoveryStrategy,
       ) {
    _keyScratch = NativeByteScratch();
    _valueScratch = NativeByteScratch();
    _outputScratch = NativeByteScratch(initialCapacity: 128);
    _scalarScratch = NativeScalarScratch();
    SenzerMMKVBindings.finalizer.attach(this, _handle, detach: this);
  }

  final String id;
  final String? path;
  final MMKVEncryptionType encryptionType;
  final MMKVMode mode;
  final bool readOnly;
  final bool compareBeforeSet;
  final MMKVRecoveryStrategy? recoveryStrategy;
  Pointer<Void> _handle;
  late final NativeByteScratch _keyScratch;
  late final NativeByteScratch _valueScratch;
  late final NativeByteScratch _outputScratch;
  late final NativeScalarScratch _scalarScratch;
  final Set<MMKVListenerRegistration> _listenerRegistrations = {};
  final String _listenerScope;

  static Pointer<Void> _open({
    required String id,
    required String? path,
    required String? encryptionKey,
    required MMKVEncryptionType encryptionType,
    required MMKVMode mode,
    required bool readOnly,
    required bool compareBeforeSet,
    required MMKVRecoveryStrategy? recoveryStrategy,
  }) {
    if (id.isEmpty ||
        id == '.' ||
        id == '..' ||
        id.contains('/') ||
        id.contains('\\')) {
      throw const MMKVException('id must be a non-empty filename-safe value.');
    }
    SenzerMMKVBindings.requireLoaded();
    final idBytes = Uint8List.fromList(utf8.encode(id));
    final pathBytes = path == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(path));
    final keyBytes = encryptionKey == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(encryptionKey));
    final idPointer = SenzerMMKVBindings.allocateBytes(idBytes);
    final pathPointer = SenzerMMKVBindings.allocateBytes(pathBytes);
    final keyPointer = SenzerMMKVBindings.allocateBytes(keyBytes);
    try {
      final result = SenzerMMKVBindings.create(
        idPointer,
        idBytes.length,
        pathPointer,
        pathBytes.length,
        keyPointer,
        keyBytes.length,
        encryptionKey == null || encryptionKey.isEmpty
            ? 0
            : encryptionType.index + 1,
        mode == MMKVMode.multiProcess ? 1 : 0,
        readOnly ? 1 : 0,
        compareBeforeSet ? 1 : 0,
        recoveryStrategy == null ? 0 : recoveryStrategy.index + 1,
      );
      if (result == nullptr) {
        throw MMKVException(SenzerMMKVBindings.nativeError());
      }
      return result;
    } finally {
      calloc.free(idPointer);
      calloc.free(pathPointer);
      if (keyBytes.isNotEmpty) {
        keyPointer
            .asTypedList(keyBytes.length)
            .fillRange(0, keyBytes.length, 0);
      }
      calloc.free(keyPointer);
    }
  }

  bool get isClosed => _handle == nullptr;

  void _ensureOpen() {
    if (isClosed) throw StateError('MMKV instance "$id" is already closed.');
  }

  int _runStatus(int status, String operation) {
    if (status < 0) {
      throw MMKVException(
        '$operation failed: ${SenzerMMKVBindings.nativeError()}',
        code: status,
      );
    }
    return status;
  }

  int _prepareKey(String key) {
    if (key.isEmpty) throw const MMKVException('key must not be empty.');
    return _keyScratch.writeUtf8(key);
  }

  void set(String key, Object value) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final status = switch (value) {
      String text => _setString(keyPointer, keyLength, text),
      bool boolean => SenzerMMKVBindings.setBoolean(
        _handle,
        keyPointer,
        keyLength,
        boolean ? 1 : 0,
      ),
      num number => SenzerMMKVBindings.setNumber(
        _handle,
        keyPointer,
        keyLength,
        number.toDouble(),
      ),
      Uint8List buffer => _setBuffer(keyPointer, keyLength, buffer),
      List<int> buffer => _setBuffer(
        keyPointer,
        keyLength,
        Uint8List.fromList(buffer),
      ),
      _ => throw ArgumentError.value(
        value,
        'value',
        'must be String, bool, num, or Uint8List',
      ),
    };
    _runStatus(status, 'set');
    _notify(key);
  }

  int _setString(Pointer<Uint8> key, int keyLength, String value) {
    final length = _valueScratch.writeUtf8(value);
    return SenzerMMKVBindings.setString(
      _handle,
      key,
      keyLength,
      _valueScratch.pointer,
      length,
    );
  }

  /// Stores an exact signed 64-bit integer without converting through a
  /// JavaScript-compatible double.
  void setInt64(String key, int value) {
    _ensureOpen();
    if (value < -0x8000000000000000 || value > 0x7fffffffffffffff) {
      throw RangeError.range(value, -0x8000000000000000, 0x7fffffffffffffff);
    }
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    _runStatus(
      SenzerMMKVBindings.setInt64(_handle, keyPointer, keyLength, value),
      'setInt64',
    );
    _notify(key);
  }

  /// Dart-friendly alias for [setInt64].
  void setInt(String key, int value) => setInt64(key, value);

  int _setBuffer(Pointer<Uint8> key, int keyLength, Uint8List value) {
    _valueScratch.writeBytes(value);
    return SenzerMMKVBindings.setBuffer(
      _handle,
      key,
      keyLength,
      _valueScratch.pointer,
      value.length,
    );
  }

  String? getString(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final length = _scalarScratch.size;
    var status = SenzerMMKVBindings.getStringInto(
      _handle,
      keyPointer,
      keyLength,
      _outputScratch.pointer,
      _outputScratch.capacity,
      length,
    );
    if (status == _bufferTooSmall) {
      _outputScratch.ensureCapacity(length.value);
      status = SenzerMMKVBindings.getStringInto(
        _handle,
        keyPointer,
        keyLength,
        _outputScratch.pointer,
        _outputScratch.capacity,
        length,
      );
    }
    if (status == 1 || status == 2) return null;
    _runStatus(status, 'getString');
    return utf8.decode(_outputScratch.view(length.value));
  }

  double? getNumber(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final status = SenzerMMKVBindings.getNumber(
      _handle,
      keyPointer,
      keyLength,
      _scalarScratch.doubleValue,
    );
    if (status == 1 || status == 2) return null;
    _runStatus(status, 'getNumber');
    return _scalarScratch.doubleValue.value;
  }

  /// Reads an exact signed 64-bit integer, or `null` when the key is absent or
  /// stores another MMKV value type.
  int? getInt64(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final status = SenzerMMKVBindings.getInt64(
      _handle,
      keyPointer,
      keyLength,
      _scalarScratch.int64,
    );
    if (status == 1 || status == 2) return null;
    _runStatus(status, 'getInt64');
    return _scalarScratch.int64.value;
  }

  /// Dart-friendly alias for [getInt64].
  int? getInt(String key) => getInt64(key);

  bool? getBoolean(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final status = SenzerMMKVBindings.getBoolean(
      _handle,
      keyPointer,
      keyLength,
      _scalarScratch.int32,
    );
    if (status == 1 || status == 2) return null;
    _runStatus(status, 'getBoolean');
    return _scalarScratch.int32.value != 0;
  }

  Uint8List? getBuffer(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final length = _scalarScratch.size;
    var status = SenzerMMKVBindings.getBufferInto(
      _handle,
      keyPointer,
      keyLength,
      _outputScratch.pointer,
      _outputScratch.capacity,
      length,
    );
    if (status == _bufferTooSmall) {
      _outputScratch.ensureCapacity(length.value);
      status = SenzerMMKVBindings.getBufferInto(
        _handle,
        keyPointer,
        keyLength,
        _outputScratch.pointer,
        _outputScratch.capacity,
        length,
      );
    }
    if (status == 1 || status == 2) return null;
    _runStatus(status, 'getBuffer');
    return Uint8List.fromList(_outputScratch.view(length.value));
  }

  bool contains(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    final status = SenzerMMKVBindings.contains(_handle, keyPointer, keyLength);
    _runStatus(status < 0 ? status : 0, 'contains');
    return status == 1;
  }

  List<String> getAllKeys() {
    _ensureOpen();
    final output = calloc<Pointer<Uint8>>();
    final outputLength = calloc<UintPtr>();
    try {
      _runStatus(
        SenzerMMKVBindings.getAllKeys(_handle, output, outputLength),
        'getAllKeys',
      );
      final bytes = output.value.asTypedList(outputLength.value);
      final keys = <String>[];
      var offset = 0;
      while (offset < bytes.length) {
        if (bytes.length - offset < 8) {
          throw const MMKVException('Native key list is truncated.');
        }
        final keyLength = ByteData.sublistView(
          bytes,
          offset,
          offset + 8,
        ).getUint64(0, Endian.host);
        offset += 8;
        if (keyLength > bytes.length - offset) {
          throw const MMKVException(
            'Native key list contains an invalid length.',
          );
        }
        keys.add(utf8.decode(bytes.sublist(offset, offset + keyLength)));
        offset += keyLength;
      }
      return keys;
    } finally {
      if (output.value != nullptr) {
        SenzerMMKVBindings.free(output.value.cast());
      }
      calloc.free(output);
      calloc.free(outputLength);
    }
  }

  bool remove(String key) {
    _ensureOpen();
    final keyLength = _prepareKey(key);
    final keyPointer = _keyScratch.pointer;
    _runStatus(
      SenzerMMKVBindings.remove(
        _handle,
        keyPointer,
        keyLength,
        _scalarScratch.int32,
      ),
      'remove',
    );
    final removed = _scalarScratch.int32.value != 0;
    if (removed) _notify(key);
    return removed;
  }

  void clearAll() {
    _ensureOpen();
    if (isReadOnly) return;
    final oldKeys = getAllKeys();
    _runStatus(SenzerMMKVBindings.clear(_handle), 'clearAll');
    for (final key in oldKeys) {
      _notify(key);
    }
  }

  void trim() {
    _ensureOpen();
    _runStatus(SenzerMMKVBindings.trim(_handle), 'trim');
  }

  /// Reloads the mmap if another process changed the file.
  void checkContentChanged() {
    _ensureOpen();
    _runStatus(
      SenzerMMKVBindings.checkContentChanged(_handle),
      'checkContentChanged',
    );
  }

  /// Drops the native value cache. The next read lazily reloads from disk.
  void clearMemoryCache() {
    _ensureOpen();
    _runStatus(
      SenzerMMKVBindings.clearMemoryCache(_handle),
      'clearMemoryCache',
    );
  }

  int get byteSize {
    _ensureOpen();
    return SenzerMMKVBindings.byteSize(_handle);
  }

  /// Backwards-compatible alias for [byteSize].
  @Deprecated('Use byteSize instead.')
  int get size => byteSize;

  /// Number of key/value pairs currently stored.
  int get length {
    _ensureOpen();
    final result = SenzerMMKVBindings.length(_handle);
    if (result < 0) {
      throw MMKVException(SenzerMMKVBindings.nativeError(), code: result);
    }
    return result;
  }

  /// Whether this instance was opened read-only.
  bool get isReadOnly {
    _ensureOpen();
    final result = SenzerMMKVBindings.isReadOnly(_handle);
    if (result < 0) {
      throw MMKVException(SenzerMMKVBindings.nativeError(), code: result);
    }
    return result == 1;
  }

  /// Whether the native file is currently encrypted.
  bool get isEncrypted {
    _ensureOpen();
    final result = SenzerMMKVBindings.isEncrypted(_handle);
    if (result < 0) {
      throw MMKVException(SenzerMMKVBindings.nativeError(), code: result);
    }
    return result == 1;
  }

  int importAllFrom(MMKV other) {
    _ensureOpen();
    other._ensureOpen();
    _runStatus(
      SenzerMMKVBindings.importAll(_handle, other._handle, _scalarScratch.size),
      'importAllFrom',
    );
    final count = _scalarScratch.size.value;
    if (count != 0) {
      for (final key in getAllKeys()) {
        _notify(key);
      }
    }
    return count;
  }

  MMKVListener addOnValueChangedListener(void Function(String key) listener) {
    _ensureOpen();
    final registration = MMKVListenerRegistry.add(_listenerScope, listener);
    _listenerRegistrations.add(registration);
    return MMKVListener(() {
      if (_listenerRegistrations.remove(registration)) {
        MMKVListenerRegistry.remove(registration);
      }
    });
  }

  void _notify(String key) {
    if (MMKVListenerRegistry.hasAnyListeners) {
      MMKVListenerRegistry.notify(_listenerScope, key);
    }
  }

  void _removeListeners() {
    for (final registration in _listenerRegistrations) {
      MMKVListenerRegistry.remove(registration);
    }
    _listenerRegistrations.clear();
  }

  @Deprecated('Use encrypt or decrypt instead.')
  void recrypt(String? encryptionKey, {MMKVEncryptionType? encryptionType}) {
    _ensureOpen();
    final key = encryptionKey == null
        ? Uint8List(0)
        : Uint8List.fromList(utf8.encode(encryptionKey));
    final pointer = SenzerMMKVBindings.allocateBytes(key);
    try {
      _runStatus(
        SenzerMMKVBindings.recrypt(
          _handle,
          pointer,
          key.length,
          encryptionKey == null
              ? 0
              : (encryptionType ?? MMKVEncryptionType.aes128).index + 1,
        ),
        'recrypt',
      );
    } finally {
      if (key.isNotEmpty) {
        pointer.asTypedList(key.length).fillRange(0, key.length, 0);
      }
      calloc.free(pointer);
    }
  }

  /// Encrypts this instance with AES-128 (default) or AES-256.
  void encrypt(String encryptionKey, {MMKVEncryptionType? encryptionType}) {
    if (encryptionKey.isEmpty) {
      throw const MMKVException('encryptionKey must not be empty.');
    }
    recrypt(
      encryptionKey,
      encryptionType: encryptionType ?? MMKVEncryptionType.aes128,
    );
  }

  /// Removes encryption and rewrites the file as plaintext.
  void decrypt() => recrypt(null);

  void close() {
    if (isClosed) return;
    _removeListeners();
    SenzerMMKVBindings.finalizer.detach(this);
    _keyScratch.dispose();
    _valueScratch.dispose();
    _outputScratch.dispose();
    _scalarScratch.dispose();
    SenzerMMKVBindings.destroy(_handle);
    _handle = nullptr;
  }

  @override
  String toString() => 'MMKV(id: $id, path: ${path ?? '<default>'})';
}

/// Drop-in factory matching react-native-mmkv's V4 naming.
MMKV createMMKV({
  String id = 'mmkv.default',
  String? path,
  String? encryptionKey,
  MMKVEncryptionType encryptionType = MMKVEncryptionType.aes128,
  MMKVMode mode = MMKVMode.singleProcess,
  bool readOnly = false,
  bool compareBeforeSet = false,
  MMKVRecoveryStrategy? recoveryStrategy,
}) => MMKV(
  id: id,
  path: path,
  encryptionKey: encryptionKey,
  encryptionType: encryptionType,
  mode: mode,
  readOnly: readOnly,
  compareBeforeSet: compareBeforeSet,
  recoveryStrategy: recoveryStrategy,
);

/// Explicitly initializes MMKV's default root directory.
///
/// The plugin initializes the platform default automatically, but callers
/// that need a shared app-group or extension directory can choose it before
/// creating an instance.
void initializeMMKV(String rootPath) {
  if (rootPath.isEmpty) {
    throw const MMKVException('rootPath must not be empty.');
  }
  SenzerMMKVBindings.requireLoaded();
  final bytes = Uint8List.fromList(utf8.encode(rootPath));
  final pointer = SenzerMMKVBindings.allocateBytes(bytes);
  try {
    final status = SenzerMMKVBindings.setDefaultPath(pointer, bytes.length);
    if (status < 0) {
      throw MMKVException(
        'initializeMMKV failed: ${SenzerMMKVBindings.nativeError()}',
        code: status,
      );
    }
  } finally {
    calloc.free(pointer);
  }
}

bool existsMMKV(String id, {String? path}) {
  SenzerMMKVBindings.requireLoaded();
  final idBytes = Uint8List.fromList(utf8.encode(id));
  final pathBytes = path == null
      ? Uint8List(0)
      : Uint8List.fromList(utf8.encode(path));
  final idPointer = SenzerMMKVBindings.allocateBytes(idBytes);
  final pathPointer = SenzerMMKVBindings.allocateBytes(pathBytes);
  try {
    final result = SenzerMMKVBindings.exists(
      idPointer,
      idBytes.length,
      pathPointer,
      pathBytes.length,
    );
    if (result < 0) {
      throw MMKVException(SenzerMMKVBindings.nativeError(), code: result);
    }
    return result == 1;
  } finally {
    calloc.free(idPointer);
    calloc.free(pathPointer);
  }
}

bool deleteMMKV(String id, {String? path}) {
  SenzerMMKVBindings.requireLoaded();
  final idBytes = Uint8List.fromList(utf8.encode(id));
  final pathBytes = path == null
      ? Uint8List(0)
      : Uint8List.fromList(utf8.encode(path));
  final idPointer = SenzerMMKVBindings.allocateBytes(idBytes);
  final pathPointer = SenzerMMKVBindings.allocateBytes(pathBytes);
  try {
    final result = SenzerMMKVBindings.deleteInstance(
      idPointer,
      idBytes.length,
      pathPointer,
      pathBytes.length,
    );
    if (result < 0) {
      throw MMKVException(SenzerMMKVBindings.nativeError(), code: result);
    }
    return result == 1;
  } finally {
    calloc.free(idPointer);
    calloc.free(pathPointer);
  }
}
