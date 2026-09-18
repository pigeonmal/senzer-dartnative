import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';
import 'integration_tests.dart';
import 'benchmark.dart';

void main() {
  // This must be the first application call so the MMKV FFI symbols and
  // Android plugin lifecycle are ready before the integration suite runs.
  DartNativePluginRegistrant.registerAll();
  runApp(const MMKVExampleApp());
}

final class MMKVExampleApp extends StatefulWidget {
  const MMKVExampleApp({super.key});

  @override
  State<MMKVExampleApp> createState() => _MMKVExampleAppState();
}

final class _MMKVExampleAppState extends State<MMKVExampleApp> {
  String _status = 'Running MMKV integration tests…';
  final List<String> _lines = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  Future<void> _runChecks() async {
    final report = await runMMKVIntegrationTests();
    if (!mounted) return;
    setState(() {
      _lines.addAll(report.passedChecks.map((name) => 'PASS  $name'));
      if (!report.passed) {
        _status = 'FAIL: ${report.failure}';
        _lines.add('FAIL  ${report.failure}');
      }
    });
    if (!report.passed) return;

    final benchmarkRows = await runMMKVBenchmarks();
    if (!mounted) return;
    setState(() {
      _lines.add('');
      _lines.add('Benchmark (1,000 operations per case):');
      _lines.addAll(benchmarkRows.map((row) =>
          '${row.name}: ${row.elapsedMicros / 1000.0} ms, ${row.opsPerSecond.toStringAsFixed(0)} ops/s'));
      _status = 'ALL PASS (${report.passedChecks.length} checks)';
    });
    print('[MMKV_TEST] ALL PASS ${report.passedChecks.length} checks');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.light,
      appBar: AppBar(title: const Text('senzer_mmkv example')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(_status, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._lines.map(Text.new),
        ],
      ),
    );
  }
}
