import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

typedef _CreateNative =
    Pointer<Void> Function(
      Pointer<Uint8>,
      UintPtr,
      Pointer<Uint8>,
      UintPtr,
      Pointer<Uint8>,
      UintPtr,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
    );
typedef _CreateDart =
    Pointer<Void> Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      int,
      int,
      int,
      int,
    );
typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _DestroyDart = void Function(Pointer<Void>);
typedef _SetStringNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      UintPtr,
      Pointer<Uint8>,
      UintPtr,
    );
typedef _SetStringDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int);
typedef _SetBooleanNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Int32);
typedef _SetBooleanDart = int Function(Pointer<Void>, Pointer<Uint8>, int, int);
typedef _SetNumberNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Double);
typedef _SetNumberDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, double);
typedef _SetInt64Native =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Int64);
typedef _SetInt64Dart = int Function(Pointer<Void>, Pointer<Uint8>, int, int);
typedef _SetBufferNative = _SetStringNative;
typedef _SetBufferDart = _SetStringDart;
typedef _GetStringNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      UintPtr,
      Pointer<Pointer<Uint8>>,
      Pointer<UintPtr>,
    );
typedef _GetStringDart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Pointer<Uint8>>,
      Pointer<UintPtr>,
    );
typedef _GetBooleanNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Pointer<Int32>);
typedef _GetBooleanDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int32>);
typedef _GetNumberNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Pointer<Double>);
typedef _GetNumberDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Double>);
typedef _GetInt64Native =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Pointer<Int64>);
typedef _GetInt64Dart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int64>);
typedef _GetBufferNative = _GetStringNative;
typedef _GetBufferDart = _GetStringDart;
typedef _ContainsNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr);
typedef _ContainsDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _GetKeyCountNative = Int32 Function(Pointer<Void>, Pointer<UintPtr>);
typedef _GetKeyCountDart = int Function(Pointer<Void>, Pointer<UintPtr>);
typedef _GetKeyAtNative =
    Int32 Function(
      Pointer<Void>,
      UintPtr,
      Pointer<Pointer<Uint8>>,
      Pointer<UintPtr>,
    );
typedef _GetKeyAtDart =
    int Function(Pointer<Void>, int, Pointer<Pointer<Uint8>>, Pointer<UintPtr>);
typedef _GetAllKeysNative =
    Int32 Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<UintPtr>);
typedef _GetAllKeysDart =
    int Function(Pointer<Void>, Pointer<Pointer<Uint8>>, Pointer<UintPtr>);
typedef _RemoveNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Pointer<Int32>);
typedef _RemoveDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Int32>);
typedef _ClearNative = Int32 Function(Pointer<Void>);
typedef _ClearDart = int Function(Pointer<Void>);
typedef _ImportNative =
    Int32 Function(Pointer<Void>, Pointer<Void>, Pointer<UintPtr>);
typedef _ImportDart =
    int Function(Pointer<Void>, Pointer<Void>, Pointer<UintPtr>);
typedef _ByteSizeNative = Uint64 Function(Pointer<Void>);
typedef _ByteSizeDart = int Function(Pointer<Void>);
typedef _LengthNative = Uint64 Function(Pointer<Void>);
typedef _LengthDart = int Function(Pointer<Void>);
typedef _InstanceFlagNative = Int32 Function(Pointer<Void>);
typedef _InstanceFlagDart = int Function(Pointer<Void>);
typedef _StatusNative = Int32 Function(Pointer<Void>);
typedef _StatusDart = int Function(Pointer<Void>);
typedef _RecryptNative =
    Int32 Function(Pointer<Void>, Pointer<Uint8>, UintPtr, Int32);
typedef _RecryptDart = int Function(Pointer<Void>, Pointer<Uint8>, int, int);
typedef _ExistsNative =
    Int32 Function(Pointer<Uint8>, UintPtr, Pointer<Uint8>, UintPtr);
typedef _ExistsDart = int Function(Pointer<Uint8>, int, Pointer<Uint8>, int);
typedef _DeleteInstanceNative = _ExistsNative;
typedef _DeleteInstanceDart = _ExistsDart;
typedef _SetDefaultPathNative = Int32 Function(Pointer<Uint8>, UintPtr);
typedef _SetDefaultPathDart = int Function(Pointer<Uint8>, int);
typedef _TrimNative = Int32 Function(Pointer<Void>);
typedef _TrimDart = int Function(Pointer<Void>);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _LastErrorDart = Pointer<Utf8> Function();

/// Low-level FFI symbols for [MMKV]. Public callers should use the typed API.
abstract final class SenzerMMKVBindings {
  static bool _loaded = false;
  static bool _unsupported = false;
  static NativeFinalizer? _finalizer;

  static late final _CreateDart create;
  static late final _DestroyDart destroy;
  static late final _SetStringDart setString;
  static late final _SetBooleanDart setBoolean;
  static late final _SetNumberDart setNumber;
  static late final _SetInt64Dart setInt64;
  static late final _SetBufferDart setBuffer;
  static late final _GetStringDart getString;
  static late final _GetBooleanDart getBoolean;
  static late final _GetNumberDart getNumber;
  static late final _GetInt64Dart getInt64;
  static late final _GetBufferDart getBuffer;
  static late final _ContainsDart contains;
  static late final _GetKeyCountDart getKeyCount;
  static late final _GetKeyAtDart getKeyAt;
  static late final _GetAllKeysDart getAllKeys;
  static late final _RemoveDart remove;
  static late final _ClearDart clear;
  static late final _TrimDart trim;
  static late final _ImportDart importAll;
  static late final _ByteSizeDart byteSize;
  static late final _LengthDart length;
  static late final _InstanceFlagDart isReadOnly;
  static late final _InstanceFlagDart isEncrypted;
  static late final _StatusDart checkContentChanged;
  static late final _StatusDart clearMemoryCache;
  static late final _RecryptDart recrypt;
  static late final _ExistsDart exists;
  static late final _DeleteInstanceDart deleteInstance;
  static late final _SetDefaultPathDart setDefaultPath;
  static late final _FreeDart free;
  static late final _LastErrorDart lastError;
  static late final Pointer<NativeFunction<_DestroyNative>> destroyPointer;

  static bool get isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  /// Loads the native symbols once. The generated DartNative registrant calls
  /// this before the first widget; direct API use also calls it lazily.
  static void loadSymbols() {
    if (_loaded || _unsupported) return;
    if (!isSupportedPlatform) {
      _unsupported = true;
      return;
    }
    final DynamicLibrary library = Platform.isAndroid
        ? DynamicLibrary.open('libsenzer_mmkv.so')
        : DynamicLibrary.process();
    create = library.lookupFunction<_CreateNative, _CreateDart>('DNMMKVCreate');
    destroy = library.lookupFunction<_DestroyNative, _DestroyDart>(
      'DNMMKVDestroy',
    );
    destroyPointer = library.lookup<NativeFunction<_DestroyNative>>(
      'DNMMKVDestroy',
    );
    setString = library.lookupFunction<_SetStringNative, _SetStringDart>(
      'DNMMKVSetString',
    );
    setBoolean = library.lookupFunction<_SetBooleanNative, _SetBooleanDart>(
      'DNMMKVSetBoolean',
    );
    setNumber = library.lookupFunction<_SetNumberNative, _SetNumberDart>(
      'DNMMKVSetNumber',
    );
    setInt64 = library.lookupFunction<_SetInt64Native, _SetInt64Dart>(
      'DNMMKVSetInt64',
    );
    setBuffer = library.lookupFunction<_SetBufferNative, _SetBufferDart>(
      'DNMMKVSetBuffer',
    );
    getString = library.lookupFunction<_GetStringNative, _GetStringDart>(
      'DNMMKVGetString',
    );
    getBoolean = library.lookupFunction<_GetBooleanNative, _GetBooleanDart>(
      'DNMMKVGetBoolean',
    );
    getNumber = library.lookupFunction<_GetNumberNative, _GetNumberDart>(
      'DNMMKVGetNumber',
    );
    getInt64 = library.lookupFunction<_GetInt64Native, _GetInt64Dart>(
      'DNMMKVGetInt64',
    );
    getBuffer = library.lookupFunction<_GetBufferNative, _GetBufferDart>(
      'DNMMKVGetBuffer',
    );
    contains = library.lookupFunction<_ContainsNative, _ContainsDart>(
      'DNMMKVContains',
    );
    getKeyCount = library.lookupFunction<_GetKeyCountNative, _GetKeyCountDart>(
      'DNMMKVGetKeyCount',
    );
    getKeyAt = library.lookupFunction<_GetKeyAtNative, _GetKeyAtDart>(
      'DNMMKVGetKeyAt',
    );
    getAllKeys = library.lookupFunction<_GetAllKeysNative, _GetAllKeysDart>(
      'DNMMKVGetAllKeys',
    );
    remove = library.lookupFunction<_RemoveNative, _RemoveDart>('DNMMKVRemove');
    clear = library.lookupFunction<_ClearNative, _ClearDart>('DNMMKVClearAll');
    trim = library.lookupFunction<_TrimNative, _TrimDart>('DNMMKVTrim');
    importAll = library.lookupFunction<_ImportNative, _ImportDart>(
      'DNMMKVImportAll',
    );
    byteSize = library.lookupFunction<_ByteSizeNative, _ByteSizeDart>(
      'DNMMKVByteSize',
    );
    length = library.lookupFunction<_LengthNative, _LengthDart>('DNMMKVLength');
    isReadOnly = library.lookupFunction<_InstanceFlagNative, _InstanceFlagDart>(
      'DNMMKVIsReadOnly',
    );
    isEncrypted = library
        .lookupFunction<_InstanceFlagNative, _InstanceFlagDart>(
          'DNMMKVIsEncrypted',
        );
    checkContentChanged = library.lookupFunction<_StatusNative, _StatusDart>(
      'DNMMKVCheckContentChanged',
    );
    clearMemoryCache = library.lookupFunction<_StatusNative, _StatusDart>(
      'DNMMKVClearMemoryCache',
    );
    recrypt = library.lookupFunction<_RecryptNative, _RecryptDart>(
      'DNMMKVRecrypt',
    );
    exists = library.lookupFunction<_ExistsNative, _ExistsDart>('DNMMKVExists');
    deleteInstance = library
        .lookupFunction<_DeleteInstanceNative, _DeleteInstanceDart>(
          'DNMMKVDelete',
        );
    setDefaultPath = library
        .lookupFunction<_SetDefaultPathNative, _SetDefaultPathDart>(
          'DNMMKVSetDefaultRootPath',
        );
    free = library.lookupFunction<_FreeNative, _FreeDart>('DNMMKVFree');
    lastError = library.lookupFunction<_LastErrorNative, _LastErrorDart>(
      'DNMMKVLastError',
    );
    _finalizer = NativeFinalizer(destroyPointer);
    if (Platform.isIOS) {
      library.lookupFunction<Void Function(), void Function()>(
        'DNMMKVInitializeDefaultPath',
      )();
    }
    _loaded = true;
  }

  static void requireLoaded() {
    loadSymbols();
    if (_unsupported) {
      throw UnsupportedError('senzer_mmkv supports iOS and Android only.');
    }
  }

  static NativeFinalizer get finalizer {
    requireLoaded();
    return _finalizer!;
  }

  static String nativeError() {
    if (!_loaded) return 'senzer_mmkv native library is not loaded.';
    final pointer = lastError();
    return pointer == nullptr
        ? 'Unknown senzer_mmkv error.'
        : pointer.toDartString();
  }

  static Pointer<Uint8> allocateBytes(List<int> bytes) {
    final pointer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    if (bytes.isNotEmpty) pointer.asTypedList(bytes.length).setAll(0, bytes);
    return pointer;
  }
}
