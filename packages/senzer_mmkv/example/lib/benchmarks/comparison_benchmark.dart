import 'benchmark_types.dart';
import 'hive_benchmark.dart';
import 'mmkv_benchmark.dart';
import 'sqlite_benchmark.dart';

final class BenchmarkStoreResult {
  const BenchmarkStoreResult({required this.store, required this.rows});

  final String store;
  final List<BenchmarkRow> rows;
}

Future<List<BenchmarkStoreResult>> runStorageBenchmarks() async {
  return <BenchmarkStoreResult>[
    BenchmarkStoreResult(store: 'senzer_mmkv', rows: await runMMKVBenchmarks()),
    BenchmarkStoreResult(
      store: 'dartnative_hive',
      rows: await runHiveBenchmarks(),
    ),
    BenchmarkStoreResult(
      store: 'dartnative_sqlite',
      rows: await runSqliteBenchmarks(),
    ),
  ];
}
