import 'dart:async';

import 'package:senzer_mmkv/senzer_mmkv.dart';

import 'benchmark_cases.dart';
import 'benchmark_types.dart';

const defaultBenchmarkOperations = 1000;
const defaultBenchmarkWarmupRounds = 2;
const defaultBenchmarkMeasuredRounds = 7;

Future<List<BenchmarkRow>> runBenchmarkCases({
  required List<BenchmarkCase> cases,
  required FutureOr<void> Function() clear,
  String logTag = 'MMKV_BENCH',
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) async {
  if (operations <= 0 || warmupRounds < 0 || measuredRounds <= 0) {
    throw RangeError('Benchmark rounds and operations must be positive.');
  }

  final rows = <BenchmarkRow>[];
  for (final benchmarkCase in cases) {
    final samplesMicros = <int>[];
    for (var round = 0; round < warmupRounds + measuredRounds; round++) {
      await clear();
      final stopwatch = Stopwatch()..start();
      await benchmarkCase.run('value-$round');
      stopwatch.stop();
      if (round >= warmupRounds) {
        samplesMicros.add(stopwatch.elapsedMicroseconds.clamp(1, 0x7fffffff));
      }
    }

    samplesMicros.sort();
    final medianMicros = samplesMicros[samplesMicros.length ~/ 2];
    final row = BenchmarkRow(
      name: benchmarkCase.name,
      elapsedMicros: medianMicros,
      opsPerSecond: operations * 1000000 / medianMicros,
    );
    rows.add(row);
    print(
      '[$logTag] ${row.name}: ${row.elapsedMs.toStringAsFixed(3)} ms, '
      '${row.opsPerSecond.toStringAsFixed(3)} ops/s',
    );
  }
  return rows;
}

Future<List<MMKVBenchmarkRow>> runMMKVBenchmarkCases(
  MMKV storage, {
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) {
  return runBenchmarkCases(
    cases: createMMKVBenchmarkCases(storage, operations: operations),
    clear: storage.clearAll,
    logTag: 'MMKV_BENCH',
    operations: operations,
    warmupRounds: warmupRounds,
    measuredRounds: measuredRounds,
  );
}
