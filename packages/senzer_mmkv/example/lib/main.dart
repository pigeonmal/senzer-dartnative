import 'package:dartnative/dartnative.dart';

import 'dartnative_plugin_registrant.dart';
import 'integration_tests.dart';
import 'security_tests.dart';
import 'benchmarks/comparison_benchmark.dart';
import 'benchmarks/path_profiler.dart';

void main() {
  // This must be the first application call so the MMKV and benchmark plugin
  // FFI symbols are ready before the integration suite and benchmarks run.
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

    final securityReport = await runMMKVSecurityTests();
    if (!mounted) return;
    setState(() {
      _lines.add('');
      _lines.add('Adversarial/security checks:');
      _lines.addAll(securityReport.passedChecks.map((name) => '  PASS  $name'));
      if (!securityReport.passed) {
        _status = 'SECURITY FAIL: ${securityReport.failure}';
        _lines.add('  FAIL  ${securityReport.failure}');
      }
    });
    if (!securityReport.passed) return;

    final benchmarkStores = await runStorageBenchmarks();
    if (!mounted) return;
    setState(() {
      _lines.add('');
      _lines.add('Benchmark (1,000 operations per case):');
      for (final benchmarkStore in benchmarkStores) {
        _lines.add(benchmarkStore.store);
        _lines.addAll(
          benchmarkStore.rows.map(
            (row) =>
                '  ${row.name}: ${row.elapsedMs.toStringAsFixed(3)} ms, ${row.opsPerSecond.toStringAsFixed(3)} ops/s',
          ),
        );
      }
    });

    final profileStages = await runPathProfiler();
    if (!mounted) return;
    setState(() {
      _lines.add('');
      _lines.add('Path Profiler (1,000 operations, median):');
      for (final stage in profileStages) {
        _lines.add(
          '  Stage ${stage.stageNumber}: ${stage.name} -> ${stage.elapsedMs.toStringAsFixed(3)} ms (${stage.nanosPerOp.toStringAsFixed(1)} ns/op)',
        );
      }
      _status =
          'ALL PASS (${report.passedChecks.length + securityReport.passedChecks.length} checks)';
    });
    print(
      '[MMKV_TEST] ALL PASS '
      '${report.passedChecks.length + securityReport.passedChecks.length} checks',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      brightness: Brightness.light,
      appBar: AppBar(title: const Text('senzer_mmkv example')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            _status,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._lines.map(Text.new),
        ],
      ),
    );
  }
}
