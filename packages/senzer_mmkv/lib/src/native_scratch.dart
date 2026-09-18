import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Reusable native memory for synchronous hot-path input/output transfers.
///
/// MMKV copies values before the native call returns, so one scratch buffer per
/// direction is safe for this synchronous API and avoids a calloc/free pair on
/// every operation.
final class NativeByteScratch {
  NativeByteScratch({int initialCapacity = 64}) {
    _replace(initialCapacity);
  }

  static final Finalizer<Pointer<Uint8>> _finalizer = Finalizer<Pointer<Uint8>>(
    (pointer) {
      if (pointer != nullptr) calloc.free(pointer);
    },
  );

  Pointer<Uint8> _pointer = nullptr;
  int _capacity = 0;

  Pointer<Uint8> get pointer => _pointer;
  int get capacity => _capacity;

  void ensureCapacity(int required) {
    if (required <= _capacity) return;
    var next = _capacity == 0 ? 64 : _capacity;
    while (next < required) {
      next *= 2;
    }
    _replace(next);
  }

  int writeUtf8(String value) {
    // Encode directly into the reusable native block. This avoids allocating
    // a temporary Dart byte list for every key/value string operation.
    final maximumBytes = value.length * 4;
    ensureCapacity(maximumBytes == 0 ? 1 : maximumBytes);
    final output = _pointer.asTypedList(_capacity);
    var offset = 0;
    for (var index = 0; index < value.length; index++) {
      var codeUnit = value.codeUnitAt(index);
      if (codeUnit <= 0x7f) {
        output[offset++] = codeUnit;
      } else if (codeUnit <= 0x7ff) {
        output[offset++] = 0xc0 | (codeUnit >> 6);
        output[offset++] = 0x80 | (codeUnit & 0x3f);
      } else if (codeUnit >= 0xd800 &&
          codeUnit <= 0xdbff &&
          index + 1 < value.length) {
        final low = value.codeUnitAt(index + 1);
        if (low >= 0xdc00 && low <= 0xdfff) {
          final codePoint =
              0x10000 + ((codeUnit - 0xd800) << 10) + (low - 0xdc00);
          output[offset++] = 0xf0 | (codePoint >> 18);
          output[offset++] = 0x80 | ((codePoint >> 12) & 0x3f);
          output[offset++] = 0x80 | ((codePoint >> 6) & 0x3f);
          output[offset++] = 0x80 | (codePoint & 0x3f);
          index++;
        } else {
          offset = _writeReplacement(output, offset);
        }
      } else if (codeUnit >= 0xdc00 && codeUnit <= 0xdfff) {
        offset = _writeReplacement(output, offset);
      } else {
        output[offset++] = 0xe0 | (codeUnit >> 12);
        output[offset++] = 0x80 | ((codeUnit >> 6) & 0x3f);
        output[offset++] = 0x80 | (codeUnit & 0x3f);
      }
    }
    return offset;
  }

  static int _writeReplacement(Uint8List output, int offset) {
    output[offset++] = 0xef;
    output[offset++] = 0xbf;
    output[offset++] = 0xbd;
    return offset;
  }

  void writeBytes(List<int> bytes) {
    ensureCapacity(bytes.isEmpty ? 1 : bytes.length);
    if (bytes.isNotEmpty) {
      final target = _pointer.asTypedList(bytes.length);
      if (bytes is Uint8List) {
        target.setRange(0, bytes.length, bytes);
      } else {
        target.setAll(0, bytes);
      }
    }
  }

  Uint8List view(int length) {
    if (length < 0 || length > _capacity) {
      throw RangeError.range(length, 0, _capacity);
    }
    return _pointer.asTypedList(length);
  }

  void dispose() {
    _finalizer.detach(this);
    if (_pointer != nullptr) {
      calloc.free(_pointer);
      _pointer = nullptr;
      _capacity = 0;
    }
  }

  void _replace(int capacity) {
    _finalizer.detach(this);
    if (_pointer != nullptr) calloc.free(_pointer);
    _pointer = calloc<Uint8>(capacity);
    _capacity = capacity;
    _finalizer.attach(this, _pointer, detach: this);
  }
}

/// One aligned native block for scalar output values and lengths.
final class NativeScalarScratch {
  NativeScalarScratch() {
    _pointer = calloc<Uint8>(_blockSize);
    _finalizer.attach(this, _pointer, detach: this);
  }

  static const _blockSize = 32;
  static final Finalizer<Pointer<Uint8>> _finalizer = Finalizer<Pointer<Uint8>>(
    (pointer) {
      if (pointer != nullptr) calloc.free(pointer);
    },
  );

  Pointer<Uint8> _pointer = nullptr;

  Pointer<Int32> get int32 => _pointer.cast<Int32>();

  Pointer<Double> get doubleValue =>
      Pointer.fromAddress(_pointer.address + 8).cast<Double>();

  Pointer<Int64> get int64 =>
      Pointer.fromAddress(_pointer.address + 16).cast<Int64>();

  Pointer<UintPtr> get size =>
      Pointer.fromAddress(_pointer.address + 24).cast<UintPtr>();

  void dispose() {
    _finalizer.detach(this);
    if (_pointer != nullptr) {
      calloc.free(_pointer);
      _pointer = nullptr;
    }
  }
}
