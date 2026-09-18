import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

import 'benchmark_types.dart';

const benchmarkStringValue = 'senzer-dartnative benchmark value';
final benchmarkBufferValue = Uint8List.fromList(
  List<int>.generate(256, (index) => index & 0xff),
);

List<BenchmarkCase> createMMKVBenchmarkCases(
  MMKV storage, {
  required int operations,
}) {
  return <BenchmarkCase>[
    BenchmarkCase(
      name: 'string write',
      run: (key) {
        for (var index = 0; index < operations; index++) {
          storage.set(key, benchmarkStringValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'string read',
      run: (key) {
        storage.set(key, benchmarkStringValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += storage.getString(key)?.length ?? 0;
        }
        if (checksum != benchmarkStringValue.length * operations) {
          throw StateError('string read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'number write',
      run: (key) {
        for (var index = 0; index < operations; index++) {
          storage.set(key, index);
        }
      },
    ),
    BenchmarkCase(
      name: 'number read',
      run: (key) {
        storage.set(key, 123.456);
        var checksum = 0.0;
        for (var index = 0; index < operations; index++) {
          checksum += storage.getNumber(key) ?? 0;
        }
        if ((checksum - 123.456 * operations).abs() > 0.000001) {
          throw StateError('number read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean write',
      run: (key) {
        for (var index = 0; index < operations; index++) {
          storage.set(key, index.isEven);
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean read',
      run: (key) {
        storage.set(key, true);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += storage.getBoolean(key) == true ? 1 : 0;
        }
        if (checksum != operations) {
          throw StateError('boolean read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer write 256B',
      run: (key) {
        for (var index = 0; index < operations; index++) {
          storage.set(key, benchmarkBufferValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer read 256B',
      run: (key) {
        storage.set(key, benchmarkBufferValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += storage.getBuffer(key)?.length ?? 0;
        }
        if (checksum != benchmarkBufferValue.length * operations) {
          throw StateError('buffer read checksum mismatch: $checksum');
        }
      },
    ),
  ];
}
