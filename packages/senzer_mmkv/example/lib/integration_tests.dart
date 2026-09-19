import 'dart:io';
import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

final class MMKVIntegrationReport {
  const MMKVIntegrationReport({
    required this.passed,
    required this.passedChecks,
    this.failure,
  });

  final bool passed;
  final List<String> passedChecks;
  final String? failure;
}

/// Exercises the complete public API against the native library on-device.
Future<MMKVIntegrationReport> runMMKVIntegrationTests() async {
  final passedChecks = <String>[];
  Directory? root;

  void check(String name, bool condition) {
    if (!condition) throw StateError(name);
    passedChecks.add(name);
    print('[MMKV_TEST] PASS $name');
  }

  try {
    root = await Directory.systemTemp.createTemp('senzer_mmkv_it_');
    initializeMMKV(root.path);
    final id = 'integration_${DateTime.now().microsecondsSinceEpoch}';
    final storage = createMMKV(id: id, path: root.path);
    final listenerKeys = <String>[];
    final listener = storage.addOnValueChangedListener(listenerKeys.add);

    check('initial flags', !storage.isEncrypted && !storage.isReadOnly);
    check('empty state', storage.length == 0 && !storage.contains('missing'));
    check('toString', storage.toString().contains(id));

    storage.set('string', 'héllo 🌍');
    storage.set('boolean', true);
    storage.set('number', 42.5);
    storage.setInt64('int64-max', 0x7fffffffffffffff);
    storage.setInt64('int64-min', -0x8000000000000000);
    storage.setInt('int-alias', -9007199254740991);
    storage.set('buffer', Uint8List.fromList(<int>[0, 1, 2, 255]));
    storage.set('list-buffer', <int>[3, 4, 5]);

    check('string round-trip', storage.getString('string') == 'héllo 🌍');
    check('boolean round-trip', storage.getBoolean('boolean') == true);
    check('number round-trip', storage.getNumber('number') == 42.5);
    check(
      'int64 max round-trip',
      storage.getInt64('int64-max') == 0x7fffffffffffffff,
    );
    check(
      'int64 min round-trip',
      storage.getInt64('int64-min') == -0x8000000000000000,
    );
    check(
      'int alias round-trip',
      storage.getInt('int-alias') == -9007199254740991,
    );
    check(
      'buffer round-trip',
      _same(storage.getBuffer('buffer'), <int>[0, 1, 2, 255]),
    );
    check(
      'list buffer round-trip',
      _same(storage.getBuffer('list-buffer'), <int>[3, 4, 5]),
    );
    // MMKV stores typed payloads as raw bytes. As in react-native-mmkv, a
    // wrong-type read may decode an interpreted value; it must not crash, and
    // the correctly typed read must remain stable.
    final wrongStringRead = storage.getString('number');
    final wrongNumberRead = storage.getNumber('string');
    final wrongBooleanRead = storage.getBoolean('number');
    final wrongBufferRead = storage.getBuffer('string');
    print(
      '[MMKV_TEST] wrong-type probes: string=$wrongStringRead number=$wrongNumberRead boolean=$wrongBooleanRead buffer=${wrongBufferRead?.length}B',
    );
    check('wrong type reads are safe', true);
    check('correct type survives probes', storage.getNumber('number') == 42.5);
    check(
      'key enumeration',
      storage.getAllKeys().toSet().containsAll(<String>{
        'string',
        'boolean',
        'number',
        'int64-max',
        'int64-min',
        'int-alias',
        'buffer',
        'list-buffer',
      }),
    );
    // ignore: deprecated_member_use
    check(
      'length and size',
      storage.length == 8 &&
          storage.size == storage.byteSize &&
          storage.byteSize > 0,
    );
    check(
      'listener delivery',
      listenerKeys.contains('string') && listenerKeys.contains('buffer'),
    );

    final genericIntegers = <String, int>{
      'generic-int-2^53-1': 0x1fffffffffffff,
      'generic-int-2^53': 0x20000000000000,
      'generic-int-2^53+1': 0x20000000000001,
      'generic-int64-min': -0x8000000000000000,
      'generic-int64-max': 0x7fffffffffffffff,
    };
    for (final entry in genericIntegers.entries) {
      storage.set(entry.key, entry.value);
    }
    check(
      'generic int dispatch preserves exact int64 boundaries',
      genericIntegers.entries.every(
        (entry) => storage.getInt64(entry.key) == entry.value,
      ),
    );
    storage.set('generic-double', 9007199254740992.0);
    check(
      'generic double dispatch remains IEEE-754',
      storage.getNumber('generic-double') == 9007199254740992.0,
    );

    check(
      'remove',
      storage.remove('list-buffer') &&
          !storage.contains('list-buffer') &&
          !storage.remove('list-buffer'),
    );
    storage.trim();
    storage.checkContentChanged();
    storage.clearMemoryCache();
    check('native maintenance calls', storage.isClosed == false);

    final importSource = MMKV(id: '${id}_source', path: root.path);
    importSource.set('imported', 'value');
    final imported = storage.importAllFrom(importSource);
    check(
      'importAllFrom',
      imported == 1 && storage.getString('imported') == 'value',
    );
    importSource.close();

    storage.encrypt(
      '01234567890123456789012345678901',
      encryptionType: MMKVEncryptionType.aes256,
    );
    check(
      'AES-256 encryption',
      storage.isEncrypted && storage.getString('string') == 'héllo 🌍',
    );
    storage.decrypt();
    check(
      'decrypt',
      !storage.isEncrypted && storage.getString('string') == 'héllo 🌍',
    );
    // ignore: deprecated_member_use
    storage.recrypt(
      '0123456789012345',
      encryptionType: MMKVEncryptionType.aes128,
    );
    check(
      'direct recrypt',
      storage.isEncrypted && storage.getString('string') == 'héllo 🌍',
    );
    // ignore: deprecated_member_use
    storage.recrypt(null);
    check(
      'direct decrypt',
      !storage.isEncrypted && storage.getString('string') == 'héllo 🌍',
    );

    // MMKV caches an instance by (root, id), so use a fresh id when changing
    // mode in the same process. This mirrors react-native-mmkv's test harness.
    final readonly = MMKV(
      id: '${id}_readonly',
      path: root.path,
      readOnly: true,
    );
    check(
      'read-only open',
      readonly.isReadOnly &&
          readonly.length == 0 &&
          !readonly.contains('missing'),
    );
    var readonlySetThrew = false;
    try {
      readonly.set('key', 'value');
    } on MMKVException {
      readonlySetThrew = true;
    }
    check('read-only set rejects writes', readonlySetThrew);
    check('read-only remove is a no-op', !readonly.remove('missing'));
    readonly.clearAll();
    readonly.close();

    final options = MMKV(
      id: '${id}_options',
      path: root.path,
      mode: MMKVMode.multiProcess,
      compareBeforeSet: true,
      recoveryStrategy: MMKVRecoveryStrategy.recoverOnError,
    );
    check('mode and recovery options', !options.isReadOnly);
    var compareBeforeSetEncryptRejected = false;
    try {
      options.encrypt('0123456789abcdef');
    } on MMKVException catch (error) {
      compareBeforeSetEncryptRejected = error.message.contains(
        'compareBeforeSet cannot be combined with encryption',
      );
    }
    check(
      'compare-before-set instance cannot be encrypted later',
      compareBeforeSetEncryptRejected && !options.isEncrypted,
    );
    options.close();

    var encryptedCompareRejected = false;
    try {
      MMKV(
        id: '${id}_encrypted_compare',
        path: root.path,
        encryptionKey: '0123456789abcdef',
        compareBeforeSet: true,
      );
    } on MMKVException catch (error) {
      encryptedCompareRejected = error.message.contains(
        'compareBeforeSet cannot be combined with encryption',
      );
    }
    check(
      'rejects compare-before-set with encryption',
      encryptedCompareRejected,
    );

    final aes128 = MMKV(
      id: '${id}_aes128',
      path: root.path,
      encryptionKey: '0123456789012345',
    );
    check(
      'constructor encryption',
      aes128.isEncrypted && aes128.getString('string') == null,
    );
    aes128.close();

    final intoTarget = Uint8List(16);
    final intoWritten = storage.getBufferInto('buffer', intoTarget);
    check(
      'getBufferInto caller-owned read',
      intoWritten == 4 && _same(intoTarget.sublist(0, 4), <int>[0, 1, 2, 255]),
    );
    storage.setString('typed-str', 'typed-val');
    storage.setBoolean('typed-bool', true);
    storage.setNumber('typed-num', 99.9);
    storage.setBuffer('typed-buf', Uint8List.fromList(<int>[10, 20]));
    check(
      'typed fast-paths round-trip',
      storage.getString('typed-str') == 'typed-val' &&
          storage.getBoolean('typed-bool') == true &&
          storage.getNumber('typed-num') == 99.9 &&
          _same(storage.getBuffer('typed-buf'), <int>[10, 20]),
    );

    listener.remove();
    storage.clearAll();
    check('clearAll', storage.length == 0 && storage.getAllKeys().isEmpty);
    storage.close();
    storage.close();

    var closedGuard = false;
    try {
      storage.getString('string');
    } on StateError {
      closedGuard = true;
    }
    check('closed guard', closedGuard && storage.isClosed);
    check(
      'exists and delete',
      existsMMKV(id, path: root.path) &&
          deleteMMKV(id, path: root.path) &&
          !existsMMKV(id, path: root.path),
    );

    await root.delete(recursive: true);
    return MMKVIntegrationReport(passed: true, passedChecks: passedChecks);
  } catch (error, stack) {
    print('[MMKV_TEST] FAIL $error\n$stack');
    if (root != null && await root.exists()) {
      await root.delete(recursive: true);
    }
    return MMKVIntegrationReport(
      passed: false,
      passedChecks: passedChecks,
      failure: '$error',
    );
  }
}

bool _same(Uint8List? actual, List<int> expected) {
  if (actual == null || actual.length != expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (actual[i] != expected[i]) return false;
  }
  return true;
}
