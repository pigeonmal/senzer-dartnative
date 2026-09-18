import 'dart:io';

import 'package:senzer_mmkv/senzer_mmkv.dart';

import 'benchmark_runner.dart';
import 'benchmark_types.dart';

export 'benchmark_runner.dart'
    show
        defaultBenchmarkMeasuredRounds,
        defaultBenchmarkOperations,
        defaultBenchmarkWarmupRounds,
        runBenchmarkCases,
        runMMKVBenchmarkCases;
export 'benchmark_types.dart' show MMKVBenchmarkCase, MMKVBenchmarkRow;

Future<List<MMKVBenchmarkRow>> runMMKVBenchmarks({
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) async {
  final root = await Directory.systemTemp.createTemp('senzer_mmkv_bench_');
  final storage = createMMKV(
    id: 'example_benchmark_${DateTime.now().microsecondsSinceEpoch}',
    path: root.path,
  );

  try {
    return await runMMKVBenchmarkCases(
      storage,
      operations: operations,
      warmupRounds: warmupRounds,
      measuredRounds: measuredRounds,
    );
  } finally {
    storage.close();
    await root.delete(recursive: true);
  }
}
