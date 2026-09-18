import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:senzer_mmkv/senzer_mmkv.dart';

import 'benchmark_cases.dart';

final class ProfileStageResult {
  const ProfileStageResult({
    required this.stageNumber,
    required this.name,
    required this.description,
    required this.elapsedMicros,
    required this.nanosPerOp,
  });

  final int stageNumber;
  final String name;
  final String description;
  final int elapsedMicros;
  final double nanosPerOp;

  double get elapsedMs => elapsedMicros / 1000.0;
}

Future<List<ProfileStageResult>> runPathProfiler({
  int operations = 1000,
  int warmupRounds = 2,
  int measuredRounds = 7,
}) async {
  final tempDir = await Directory.systemTemp.createTemp('mmkv_profiler_');
  final plainStorage = MMKV(
    id: 'profiler_plain_${DateTime.now().microsecondsSinceEpoch}',
    path: tempDir.path,
  );
  final encStorage = MMKV(
    id: 'profiler_enc_${DateTime.now().microsecondsSinceEpoch}',
    path: tempDir.path,
    encryptionKey: '0123456789012345',
    encryptionType: MMKVEncryptionType.aes128,
  );

  try {
    final results = <ProfileStageResult>[];

    int measureMedian(void Function() action) {
      final samples = <int>[];
      for (var r = 0; r < warmupRounds + measuredRounds; r++) {
        final sw = Stopwatch()..start();
        action();
        sw.stop();
        if (r >= warmupRounds) {
          samples.add(sw.elapsedMicroseconds.clamp(1, 0x7fffffff));
        }
      }
      samples.sort();
      return samples[samples.length ~/ 2];
    }

    const testKey = 'benchmark_key';
    final keyScratch = plainStorage.keyScratch;
    final valScratch = plainStorage.valueScratch;
    final scalarScratch = plainStorage.scalarScratch;
    final handle = plainStorage.nativeHandle;

    final keyLen = keyScratch.writeUtf8(testKey);
    final keyPtr = keyScratch.pointer;
    final valLen = valScratch.writeUtf8(benchmarkStringValue);
    final valPtr = valScratch.pointer;

    // 1. Dart dispatch and type conversion
    // Measure polymorphic switch overhead vs direct invocation
    void directCall(String key, String value) {}
    void polymorphicCall(String key, Object value) {
      switch (value) {
        case String _:
          break;
        case num _:
          break;
        case bool _:
          break;
        case Uint8List _:
          break;
        default:
          break;
      }
    }

    final directElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        directCall(testKey, benchmarkStringValue);
      }
    });
    final polyElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        polymorphicCall(testKey, benchmarkStringValue);
      }
    });
    final dispatchMicros = (polyElapsed - directElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 1,
      name: 'Dart dispatch & type conversion',
      description: 'Polymorphic Object switch vs direct typed call',
      elapsedMicros: dispatchMicros,
      nanosPerOp: (dispatchMicros * 1000.0) / operations,
    ));

    // 2. UTF-8 encoding
    final encodeKeyElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        keyScratch.writeUtf8(testKey);
      }
    });
    final encodeValElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        valScratch.writeUtf8(benchmarkStringValue);
      }
    });
    final totalEncodeMicros = encodeKeyElapsed + encodeValElapsed;
    results.add(ProfileStageResult(
      stageNumber: 2,
      name: 'UTF-8 encoding (key + value)',
      description: 'writeUtf8 for key (${testKey.length}B) + value (${benchmarkStringValue.length}B)',
      elapsedMicros: totalEncodeMicros,
      nanosPerOp: (totalEncodeMicros * 1000.0) / operations,
    ));

    // 3. FFI calls (pure call trampoline / transition)
    final ffiNoopElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.profileNoop(handle, keyPtr, keyLen, valPtr, valLen);
      }
    });
    results.add(ProfileStageResult(
      stageNumber: 3,
      name: 'FFI call overhead',
      description: 'Raw Dart FFI trampoline call (DNMMKVProfileNoop)',
      elapsedMicros: ffiNoopElapsed,
      nanosPerOp: (ffiNoopElapsed * 1000.0) / operations,
    ));

    // 4. C ABI validation
    final ffiValidateElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.profileValidate(handle, keyPtr, keyLen, valPtr, valLen);
      }
    });
    final cAbiValidationMicros = (ffiValidateElapsed - ffiNoopElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 4,
      name: 'C ABI validation',
      description: 'DNMMKVProfileValidate (null checks, length checks, toView) delta',
      elapsedMicros: cAbiValidationMicros,
      nanosPerOp: (cAbiValidationMicros * 1000.0) / operations,
    ));

    // 5. Handle access
    // ProfileValidate already does value(handle) -> dereferences handle->shared->value
    // Measure delta against passing nullptr
    final invalidHandleElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.profileValidate(nullptr, keyPtr, keyLen, valPtr, valLen);
      }
    });
    final handleAccessMicros = (ffiValidateElapsed - invalidHandleElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 5,
      name: 'Handle access',
      description: 'Handle pointer dereference and shared-instance lookup',
      elapsedMicros: handleAccessMicros,
      nanosPerOp: (handleAccessMicros * 1000.0) / operations,
    ));

    // 6. MMKV locking and serialization (Set & Get)
    final rawSetStringElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.setString(handle, keyPtr, keyLen, valPtr, valLen);
      }
    });
    final mmkvLockSetMicros = (rawSetStringElapsed - ffiValidateElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 6,
      name: 'MMKV locking & serialization (write)',
      description: 'Native MMKV instance->set string mutex + serialization delta',
      elapsedMicros: mmkvLockSetMicros,
      nanosPerOp: (mmkvLockSetMicros * 1000.0) / operations,
    ));

    // Prime the value for read tests
    SenzerMMKVBindings.setString(handle, keyPtr, keyLen, valPtr, valLen);

    // 7. Encryption
    final encHandle = encStorage.nativeHandle;
    final encKeyScratch = encStorage.keyScratch;
    final encValScratch = encStorage.valueScratch;
    final encKeyLen = encKeyScratch.writeUtf8(testKey);
    final encValLen = encValScratch.writeUtf8(benchmarkStringValue);
    final rawEncSetStringElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.setString(
          encHandle,
          encKeyScratch.pointer,
          encKeyLen,
          encValScratch.pointer,
          encValLen,
        );
      }
    });
    final encOverheadMicros = (rawEncSetStringElapsed - rawSetStringElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 7,
      name: 'Encryption overhead (AES-128)',
      description: 'Encrypted MMKV setString delta vs unencrypted',
      elapsedMicros: encOverheadMicros,
      nanosPerOp: (encOverheadMicros * 1000.0) / operations,
    ));

    // 8. Native allocations
    // Compare DNMMKVGetString (malloc copyOut) vs DNMMKVGetStringView (thread-local scratch)
    final getStringViewElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.getStringView(
          handle,
          keyPtr,
          keyLen,
          scalarScratch.pointerValue,
          scalarScratch.size,
        );
      }
    });
    final getStringMallocElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        SenzerMMKVBindings.getString(
          handle,
          keyPtr,
          keyLen,
          scalarScratch.pointerValue,
          scalarScratch.size,
        );
        final ptr = scalarScratch.pointerValue.value;
        if (ptr != nullptr) {
          SenzerMMKVBindings.free(ptr.cast<Void>());
        }
      }
    });
    final nativeAllocMicros = (getStringMallocElapsed - getStringViewElapsed).clamp(0, 0x7fffffff);
    results.add(ProfileStageResult(
      stageNumber: 8,
      name: 'Native allocations (malloc/free)',
      description: 'DNMMKVGetString (malloc+free) delta vs DNMMKVGetStringView (reusable scratch)',
      elapsedMicros: nativeAllocMicros,
      nanosPerOp: (nativeAllocMicros * 1000.0) / operations,
    ));

    // 9. Buffer copies (256B)
    final buffer256 = benchmarkBufferValue;
    final bufferWriteCopyElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        valScratch.writeBytes(buffer256);
      }
    });
    // Set buffer in storage
    SenzerMMKVBindings.setBuffer(handle, keyPtr, keyLen, valScratch.pointer, buffer256.length);
    SenzerMMKVBindings.getBufferView(
      handle,
      keyPtr,
      keyLen,
      scalarScratch.pointerValue,
      scalarScratch.size,
    );
    final nativeBytes = scalarScratch.pointerValue.value.asTypedList(scalarScratch.size.value);
    final bufferReadFromListElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        Uint8List.fromList(nativeBytes);
      }
    });
    final bufferReadSetRangeElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        final target = Uint8List(256);
        target.setRange(0, 256, nativeBytes);
      }
    });
    results.add(ProfileStageResult(
      stageNumber: 9,
      name: 'Buffer copies (256B)',
      description: 'Write copy (${(bufferWriteCopyElapsed*1000.0/operations).toStringAsFixed(1)}ns) + Read Uint8List.fromList (${(bufferReadFromListElapsed*1000.0/operations).toStringAsFixed(1)}ns, setRange: ${(bufferReadSetRangeElapsed*1000.0/operations).toStringAsFixed(1)}ns)',
      elapsedMicros: bufferWriteCopyElapsed + bufferReadFromListElapsed,
      nanosPerOp: ((bufferWriteCopyElapsed + bufferReadFromListElapsed) * 1000.0) / operations,
    ));

    // 10. Dart materialization (String read from native memory)
    final strValLen = valScratch.writeUtf8(benchmarkStringValue);
    SenzerMMKVBindings.setString(handle, keyPtr, keyLen, valScratch.pointer, strValLen);
    SenzerMMKVBindings.getStringView(
      handle,
      keyPtr,
      keyLen,
      scalarScratch.pointerValue,
      scalarScratch.size,
    );
    final strBytes = scalarScratch.pointerValue.value.asTypedList(scalarScratch.size.value);
    final materializeCharCodesElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        String.fromCharCodes(strBytes);
      }
    });
    final materializeUtf8DecodeElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        utf8.decode(strBytes);
      }
    });
    final strLen = scalarScratch.size.value;
    final ptr = scalarScratch.pointerValue.value;
    final materializeToDartStringElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        ptr.cast<Utf8>().toDartString(length: strLen);
      }
    });
    final fullGetStringElapsed = measureMedian(() {
      for (var i = 0; i < operations; i++) {
        plainStorage.getString(testKey);
      }
    });
    results.add(ProfileStageResult(
      stageNumber: 10,
      name: 'Dart materialization (String 33B)',
      description: 'fromCharCodes: ${(materializeCharCodesElapsed*1000.0/operations).toStringAsFixed(1)}ns, utf8.decode: ${(materializeUtf8DecodeElapsed*1000.0/operations).toStringAsFixed(1)}ns, toDartString: ${(materializeToDartStringElapsed*1000.0/operations).toStringAsFixed(1)}ns, full getString: ${(fullGetStringElapsed*1000.0/operations).toStringAsFixed(1)}ns',
      elapsedMicros: materializeCharCodesElapsed,
      nanosPerOp: (materializeCharCodesElapsed * 1000.0) / operations,
    ));

    // Print summary
    print('==================== MMKV COMPLETE PATH PROFILE ($operations ops, median of $measuredRounds) ====================');
    for (final r in results) {
      print('[MMKV_PROFILE] Stage ${r.stageNumber}: ${r.name.padRight(36)} -> ${r.elapsedMs.toStringAsFixed(3)} ms (${r.nanosPerOp.toStringAsFixed(1)} ns/op) | ${r.description}');
    }
    print('================================================================================================');

    return results;
  } finally {
    plainStorage.close();
    encStorage.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  }
}
