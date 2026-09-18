import 'dart:io';

import 'package:dartnative_hive/dartnative_hive.dart';

import 'benchmark_cases.dart';
import 'benchmark_runner.dart';
import 'benchmark_types.dart';

List<BenchmarkCase> createHiveBenchmarkCases(
  Box<dynamic> box, {
  required int operations,
}) {
  return <BenchmarkCase>[
    BenchmarkCase(
      name: 'string write',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await box.put(key, benchmarkStringValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'string read',
      run: (key) async {
        await box.put(key, benchmarkStringValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += (box.get(key) as String?)?.length ?? 0;
        }
        if (checksum != benchmarkStringValue.length * operations) {
          throw StateError('string read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'number write',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await box.put(key, index);
        }
      },
    ),
    BenchmarkCase(
      name: 'number read',
      run: (key) async {
        await box.put(key, 123.456);
        var checksum = 0.0;
        for (var index = 0; index < operations; index++) {
          checksum += (box.get(key) as num?)?.toDouble() ?? 0;
        }
        if ((checksum - 123.456 * operations).abs() > 0.000001) {
          throw StateError('number read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean write',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await box.put(key, index.isEven);
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean read',
      run: (key) async {
        await box.put(key, true);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += box.get(key) == true ? 1 : 0;
        }
        if (checksum != operations) {
          throw StateError('boolean read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer write 256B',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await box.put(key, benchmarkBufferValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer read 256B',
      run: (key) async {
        await box.put(key, benchmarkBufferValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          final value = box.get(key);
          checksum += value is List<int> ? value.length : 0;
        }
        if (checksum != benchmarkBufferValue.length * operations) {
          throw StateError('buffer read checksum mismatch: $checksum');
        }
      },
    ),
  ];
}

Future<List<BenchmarkRow>> runHiveBenchmarks({
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) async {
  final root = await Directory.systemTemp.createTemp('senzer_hive_bench_');
  final boxName = 'benchmark_${DateTime.now().microsecondsSinceEpoch}';
  Hive.init(root.path);
  final box = await Hive.openBox<dynamic>(boxName);

  try {
    return await runBenchmarkCases(
      cases: createHiveBenchmarkCases(box, operations: operations),
      clear: () async {
        await box.clear();
      },
      logTag: 'HIVE_BENCH',
      operations: operations,
      warmupRounds: warmupRounds,
      measuredRounds: measuredRounds,
    );
  } finally {
    await box.close();
    await Hive.deleteBoxFromDisk(boxName, path: root.path);
    await Hive.close();
    await root.delete(recursive: true);
  }
}
