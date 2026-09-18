import 'dart:io';
import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

final class MMKVBenchmarkRow {
  const MMKVBenchmarkRow({
    required this.name,
    required this.elapsedMicros,
    required this.opsPerSecond,
  });

  final String name;
  final int elapsedMicros;
  final double opsPerSecond;
}

/// Small on-device smoke benchmark kept in the example app so performance
/// regressions can be checked alongside functional behavior.
Future<List<MMKVBenchmarkRow>> runMMKVBenchmarks({int iterations = 1000}) async {
  final root = await Directory.systemTemp.createTemp('senzer_mmkv_bench_');
  final storage = createMMKV(
    id: 'example_benchmark_${DateTime.now().microsecondsSinceEpoch}',
    path: root.path,
  );
  final payload = Uint8List.fromList(List<int>.generate(256, (index) => index & 0xff));
  final rows = <MMKVBenchmarkRow>[];

  try {
    void measure(String name, void Function(int index) operation) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        operation(i);
      }
      stopwatch.stop();
      final elapsedMicros = stopwatch.elapsedMicroseconds;
      final opsPerSecond = elapsedMicros == 0
          ? double.infinity
          : iterations * 1000000 / elapsedMicros;
      final row = MMKVBenchmarkRow(
        name: name,
        elapsedMicros: elapsedMicros,
        opsPerSecond: opsPerSecond,
      );
      rows.add(row);
      print('[MMKV_BENCH] ${row.name}: ${row.elapsedMicros} us, ${row.opsPerSecond.toStringAsFixed(0)} ops/s');
    }

    for (var i = 0; i < iterations; i++) {
      storage.set('string-$i', 'senzer_mmkv benchmark value');
      storage.set('number-$i', i.toDouble());
      storage.set('boolean-$i', i.isEven);
      storage.set('buffer-$i', payload);
    }
    measure('string write', (i) => storage.set('string-$i', 'senzer_mmkv benchmark value'));
    measure('string read', (i) => storage.getString('string-$i'));
    measure('number write', (i) => storage.set('number-$i', i.toDouble()));
    measure('number read', (i) => storage.getNumber('number-$i'));
    measure('boolean write', (i) => storage.set('boolean-$i', i.isEven));
    measure('boolean read', (i) => storage.getBoolean('boolean-$i'));
    measure('buffer write 256B', (i) => storage.set('buffer-$i', payload));
    measure('buffer read 256B', (i) => storage.getBuffer('buffer-$i'));
    return rows;
  } finally {
    storage.close();
    await root.delete(recursive: true);
  }
}
