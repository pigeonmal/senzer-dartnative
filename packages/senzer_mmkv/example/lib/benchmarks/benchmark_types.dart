import 'dart:async';

typedef BenchmarkOperation = FutureOr<void> Function(String key);

final class BenchmarkCase {
  const BenchmarkCase({required this.name, required this.run});

  final String name;
  final BenchmarkOperation run;
}

final class BenchmarkRow {
  const BenchmarkRow({
    required this.name,
    required this.elapsedMicros,
    required this.opsPerSecond,
  });

  final String name;
  final int elapsedMicros;
  final double opsPerSecond;

  double get elapsedMs => elapsedMicros / 1000.0;
}

typedef MMKVBenchmarkCase = BenchmarkCase;
typedef MMKVBenchmarkRow = BenchmarkRow;
