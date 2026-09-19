import 'dart:convert';

import 'package:dartnative_shared_preferences/dartnative_shared_preferences.dart';

import 'benchmark_cases.dart';
import 'benchmark_runner.dart';
import 'benchmark_types.dart';

List<BenchmarkCase> createSharedPreferencesBenchmarkCases(
  SharedPreferences preferences, {
  required int operations,
}) {
  return <BenchmarkCase>[
    BenchmarkCase(
      name: 'string write',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await _write(preferences.setString(key, benchmarkStringValue));
        }
      },
    ),
    BenchmarkCase(
      name: 'string read',
      run: (key) async {
        await _write(preferences.setString(key, benchmarkStringValue));
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += preferences.getString(key)?.length ?? 0;
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
          await _write(preferences.setInt(key, index));
        }
      },
    ),
    BenchmarkCase(
      name: 'number read',
      run: (key) async {
        await _write(preferences.setDouble(key, 123.456));
        var checksum = 0.0;
        for (var index = 0; index < operations; index++) {
          checksum += preferences.getDouble(key) ?? 0;
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
          await _write(preferences.setBool(key, index.isEven));
        }
      },
    ),
    BenchmarkCase(
      name: 'boolean read',
      run: (key) async {
        await _write(preferences.setBool(key, true));
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          checksum += preferences.getBool(key) == true ? 1 : 0;
        }
        if (checksum != operations) {
          throw StateError('boolean read checksum mismatch: $checksum');
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer write 256B (base64 String)',
      run: (key) async {
        for (var index = 0; index < operations; index++) {
          await _write(
            preferences.setString(key, base64Encode(benchmarkBufferValue)),
          );
        }
      },
    ),
    BenchmarkCase(
      name: 'buffer read 256B (base64 String)',
      run: (key) async {
        await _write(
          preferences.setString(key, base64Encode(benchmarkBufferValue)),
        );
        var checksum = 0;
        for (var index = 0; index < operations; index++) {
          final value = preferences.getString(key);
          checksum += value == null ? 0 : base64Decode(value).length;
        }
        if (checksum != benchmarkBufferValue.length * operations) {
          throw StateError('buffer read checksum mismatch: $checksum');
        }
      },
    ),
  ];
}

Future<List<BenchmarkRow>> runSharedPreferencesBenchmarks({
  int operations = defaultBenchmarkOperations,
  int warmupRounds = defaultBenchmarkWarmupRounds,
  int measuredRounds = defaultBenchmarkMeasuredRounds,
}) async {
  final preferences = await SharedPreferences.getInstance();
  return runBenchmarkCases(
    cases: createSharedPreferencesBenchmarkCases(
      preferences,
      operations: operations,
    ),
    clear: () async {
      if (!await preferences.clear()) {
        throw StateError('Could not clear benchmark preferences.');
      }
    },
    logTag: 'SHARED_PREFERENCES_BENCH',
    operations: operations,
    warmupRounds: warmupRounds,
    measuredRounds: measuredRounds,
  );
}

Future<void> _write(Future<bool> result) async {
  if (!await result) {
    throw StateError('Shared Preferences benchmark write failed.');
  }
}
