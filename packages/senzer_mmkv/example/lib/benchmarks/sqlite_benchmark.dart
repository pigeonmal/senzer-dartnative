import 'dart:io';
import 'dart:typed_data';

import 'package:dartnative_sqlite/dartnative_sqlite.dart';

import 'benchmark_cases.dart';
import 'benchmark_runner.dart';
import 'benchmark_types.dart';

const _table = 'benchmark_values';

Future<void> _insert(
  SqliteDatabase database,
  String key,
  String column,
  Object value,
) {
  return database.rawInsert(
    'INSERT OR REPLACE INTO $_table (entry_key, $column) VALUES (?, ?)',
    [key, value],
  );
}

Future<List<Map<String, Object?>>> _read(
  SqliteDatabase database,
  String key,
  String column,
) {
  return database.rawQuery('SELECT $column FROM $_table WHERE entry_key = ?', [
    key,
  ]);
}

List<BenchmarkCase> createSqliteBenchmarkCases(
  SqliteDatabase database, {
  required int operations,
}) {
  return <BenchmarkCase>[
    BenchmarkCase(
      name: 'string write',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await _insert(database, key, 'string_value', benchmarkStringValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'string read',
      run: (key) async {
        await _insert(database, key, 'string_value', benchmarkStringValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          final rows = await _read(database, key, 'string_value');
          checksum += (rows.first['string_value'] as String?)?.length ?? 0;
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
          await _insert(database, key, 'number_value', index);
        }
      },
    ),
    BenchmarkCase(
      name: 'number read',
      run: (key) async {
        await _insert(database, key, 'number_value', 123.456);
        var checksum = 0.0;
        for (var index = 0; index < operations; index++) {
          final rows = await _read(database, key, 'number_value');
          checksum += (rows.first['number_value'] as num?)?.toDouble() ?? 0;
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
          await _insert(database, key, 'boolean_value', index.isEven ? 1 : 0);
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean read',
      run: (key) async {
        await _insert(database, key, 'boolean_value', 1);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          final rows = await _read(database, key, 'boolean_value');
          checksum += rows.first['boolean_value'] == 1 ? 1 : 0;
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
          await _insert(database, key, 'buffer_value', benchmarkBufferValue);
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer read 256B',
      run: (key) async {
        await _insert(database, key, 'buffer_value', benchmarkBufferValue);
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          final rows = await _read(database, key, 'buffer_value');
          checksum += _byteLength(rows.first['buffer_value']);
        }
        if (checksum != benchmarkBufferValue.length * operations) {
          throw StateError('buffer read checksum mismatch: $checksum');
        }
      },
    ),
  ];
}

Future<List<BenchmarkRow>> runSqliteBenchmarks({
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) async {
  final root = await Directory.systemTemp.createTemp('senzer_sqlite_bench_');
  final database = await Sqlite.open(
    '${root.path}/benchmark.sqlite',
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $_table (
          entry_key TEXT PRIMARY KEY,
          string_value TEXT,
          number_value REAL,
          boolean_value INTEGER,
          buffer_value BLOB
        )
      ''');
    },
  );

  try {
    return await runBenchmarkCases(
      cases: createSqliteBenchmarkCases(database, operations: operations),
      clear: () async {
        await database.delete(_table);
      },
      logTag: 'SQLITE_BENCH',
      operations: operations,
      warmupRounds: warmupRounds,
      measuredRounds: measuredRounds,
    );
  } finally {
    await database.close();
    await root.delete(recursive: true);
  }
}

int _byteLength(Object? value) {
  return switch (value) {
    Uint8List bytes => bytes.length,
    List<int> bytes => bytes.length,
    _ => 0,
  };
}
