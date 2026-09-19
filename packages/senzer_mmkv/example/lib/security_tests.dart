import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

/// Result of the bounded, on-device adversarial suite.
final class MMKVSecurityReport {
  const MMKVSecurityReport({
    required this.passed,
    required this.passedChecks,
    this.failure,
  });

  final bool passed;
  final List<String> passedChecks;
  final String? failure;
}

/// Exercises hostile-but-realistic inputs against the native FFI boundary.
///
/// This is intentionally deterministic and bounded so it can run from the
/// example app in a debug/profile build. A process crash is a test failure even
/// when Dart cannot catch it, which is useful for catching native memory bugs.
Future<MMKVSecurityReport> runMMKVSecurityTests() async {
  final passedChecks = <String>[];
  Directory? root;
  try {
    root = await Directory.systemTemp.createTemp('senzer_mmkv_security_');
    initializeMMKV(root.path);

    void check(String name, bool condition) {
      if (!condition) throw StateError(name);
      passedChecks.add(name);
    }

    void expectMMKVError(String name, void Function() action, {int? code}) {
      Object? caught;
      try {
        action();
      } catch (error) {
        caught = error;
      }
      check(
        name,
        caught is MMKVException && (code == null || caught.code == code),
      );
    }

    void expectStateError(String name, void Function() action) {
      Object? caught;
      try {
        action();
      } catch (error) {
        caught = error;
      }
      check(name, caught is StateError);
    }

    void expectNoNativeCrash(String name, void Function() action) {
      // A Dart exception is acceptable for malformed/type-confusion probes;
      // the important invariant is that the native process remains alive.
      try {
        action();
      } catch (_) {
        // Deliberately ignored: callers still verify the store afterwards.
      }
      passedChecks.add(name);
    }

    for (final id in <String>[
      '',
      '.',
      '..',
      '../escape',
      r'..\escape',
      '/absolute',
      'line\nbreak',
      'tab\tbreak',
      'nul\u0000byte',
      '\u007fdelete',
    ]) {
      expectMMKVError('rejects hostile instance id ${_describe(id)}', () {
        MMKV(id: id, path: root!.path);
      });
    }
    expectMMKVError('rejects a control character in a root path', () {
      initializeMMKV('${root!.path}\u0000poison');
    });

    final storage = MMKV(
      id: 'adversarial_values_${DateTime.now().microsecondsSinceEpoch}',
      path: root.path,
    );
    try {
      final hostileStrings = <String>[
        "' OR 1=1; DROP TABLE settings; --",
        r'../../etc/passwd',
        r'$(touch /tmp/senzer-mmkv-pwned) && `id`',
        '<script>alert(1)</script>',
        'line\nbreak\tcarriage\rreturn\u0000nul',
        'emoji 😀 café 汉字 عربى',
      ];
      for (var index = 0; index < hostileStrings.length; index++) {
        final key = 'hostile-string-$index';
        final value = hostileStrings[index];
        storage.setString(key, value);
        check(
          'round-trips hostile string $index',
          storage.getString(key) == value,
        );
      }

      const malformedSurrogates = 'before\uD800middle\uDC00after';
      storage.setString('malformed-surrogates', malformedSurrogates);
      check(
        'replaces malformed UTF-16 without crashing',
        storage.getString('malformed-surrogates') == 'before�middle�after',
      );

      final hostileKeys = <String>[
        "key' OR '1'='1",
        r'key/../../escape',
        'key\nline',
        'ключ-🔐',
      ];
      for (var index = 0; index < hostileKeys.length; index++) {
        final key = hostileKeys[index];
        storage.setString(key, 'opaque-$index');
        check(
          'treats hostile key $index as opaque bytes',
          storage.getString(key) == 'opaque-$index',
        );
      }
      expectMMKVError('rejects NUL characters in write keys', () {
        storage.setString('key\u0000nul', 'must-not-be-stored');
      });
      expectMMKVError('rejects NUL characters in read keys', () {
        storage.getString('key\u0000nul');
      });
      expectMMKVError('rejects NUL characters in contains keys', () {
        storage.contains('key\u0000nul');
      });
      expectMMKVError('rejects NUL characters in remove keys', () {
        storage.remove('key\u0000nul');
      });
      final enumeratedKeys = storage.getAllKeys().toSet();
      final missingKeys = hostileKeys
          .where((key) => !enumeratedKeys.contains(key))
          .toList();
      if (missingKeys.isNotEmpty) {
        throw StateError(
          'enumerated key list omitted ${missingKeys.map(_describe).toList()}',
        );
      }
      passedChecks.add('enumerates hostile keys without truncation');

      for (final length in <int>[0, 1, 7, 16, 255, 4096, 70000]) {
        final payload = Uint8List.fromList(
          List<int>.generate(length, (index) => (index * 31 + 7) & 0xff),
        );
        final key = 'binary-$length';
        storage.setBuffer(key, payload);
        final result = storage.getBuffer(key);
        check(
          'round-trips binary payload of $length bytes',
          _same(result, payload),
        );
        final target = Uint8List(length);
        final written = storage.getBufferInto(key, target);
        check(
          'caller-owned binary read of $length bytes',
          written == length && _same(target, payload),
        );
      }

      final shortTarget = Uint8List.fromList(<int>[0xa5, 0xa5]);
      expectMMKVError(
        'rejects an undersized caller-owned output buffer',
        () => storage.getBufferInto('binary-16', shortTarget),
        code: -4,
      );
      check(
        'undersized output remains untouched',
        shortTarget.every((byte) => byte == 0xa5),
      );

      final random = Random(0x5eed);
      for (var index = 0; index < 96; index++) {
        final key =
            'fuzz-$index-${_randomAscii(random, 1 + random.nextInt(40))}';
        final payload = Uint8List.fromList(
          List<int>.generate(random.nextInt(2049), (_) => random.nextInt(256)),
        );
        storage.setBuffer(key, payload);
        check(
          'deterministic binary fuzz case $index',
          _same(storage.getBuffer(key), payload),
        );
      }

      for (final value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -0.0,
        double.maxFinite,
        -double.maxFinite,
      ]) {
        expectNoNativeCrash(
          'accepts hostile floating-point input ${_describe(value)}',
          () {
            storage.setNumber('number-${_describe(value)}', value);
            storage.getNumber('number-${_describe(value)}');
          },
        );
      }
      storage.setInt64('int64-max', 0x7fffffffffffffff);
      storage.setInt64('int64-min', -0x8000000000000000);
      check(
        'preserves signed 64-bit maximum',
        storage.getInt64('int64-max') == 0x7fffffffffffffff,
      );
      check(
        'preserves signed 64-bit minimum',
        storage.getInt64('int64-min') == -0x8000000000000000,
      );

      storage.setString('type-string', 'not-a-number');
      storage.setNumber('type-number', 12.5);
      storage.setBuffer(
        'type-buffer',
        Uint8List.fromList(<int>[0xff, 0x00, 0x01]),
      );
      expectNoNativeCrash('survives string/number/buffer type confusion', () {
        storage.getString('type-number');
        storage.getNumber('type-string');
        storage.getString('type-buffer');
        storage.getBuffer('type-string');
      });
      check(
        'correct value survives type confusion',
        storage.getNumber('type-number') == 12.5,
      );

      var callbackCount = 0;
      MMKVListener? selfRemoving;
      selfRemoving = storage.addOnValueChangedListener((_) {
        callbackCount++;
        selfRemoving!.remove();
      });
      storage.setString('listener-reentrancy', 'first');
      storage.setString('listener-reentrancy', 'second');
      check('listener snapshot supports self-removal', callbackCount == 1);

      storage.close();
      storage.close();
      expectStateError('closed storage rejects native operations', () {
        storage.getString('closed');
      });
      check('closed storage guard remains deterministic', storage.isClosed);
    } finally {
      storage.close();
    }

    for (final invalid in <String>['0123456789abcde', '0123456789abcdef0']) {
      expectMMKVError('rejects invalid AES-128 key length ${invalid.length}', () {
        MMKV(
          id: 'bad-aes128-${invalid.length}-${DateTime.now().microsecondsSinceEpoch}',
          path: root!.path,
          encryptionKey: invalid,
        );
      });
    }
    for (final invalid in <String>[
      '0123456789abcdefghijklmnopqrstu',
      '0123456789abcdefghijklmnopqrstuvw',
    ]) {
      expectMMKVError('rejects invalid AES-256 key length ${invalid.length}', () {
        MMKV(
          id: 'bad-aes256-${invalid.length}-${DateTime.now().microsecondsSinceEpoch}',
          path: root!.path,
          encryptionKey: invalid,
          encryptionType: MMKVEncryptionType.aes256,
        );
      });
    }

    final encrypted = MMKV(
      id: 'valid-encryption-${DateTime.now().microsecondsSinceEpoch}',
      path: root.path,
      encryptionKey: 'éééééééé', // 16 UTF-8 bytes, 8 Dart code points.
    );
    try {
      check('accepts an exact UTF-8-byte AES-128 key', encrypted.isEncrypted);
      encrypted.setString('secret', 'opaque secret');
      check(
        'encrypted value round-trip',
        encrypted.getString('secret') == 'opaque secret',
      );
      expectMMKVError(
        'rejects short re-encryption key',
        () => encrypted.encrypt('short'),
      );
    } finally {
      encrypted.close();
    }

    final encrypted256 = MMKV(
      id: 'valid-encryption-256-${DateTime.now().microsecondsSinceEpoch}',
      path: root.path,
      encryptionKey: '0123456789abcdef0123456789abcdef',
      encryptionType: MMKVEncryptionType.aes256,
    );
    check('accepts an exact AES-256 key', encrypted256.isEncrypted);
    encrypted256.close();

    final spoofedId = 'same-id-${DateTime.now().microsecondsSinceEpoch}';
    final tenantA = MMKV(id: spoofedId, path: '${root.path}/tenant-a');
    final tenantB = MMKV(id: spoofedId, path: '${root.path}/tenant-b');
    try {
      tenantA.setString('tenant-secret', 'A');
      tenantB.setString('tenant-secret', 'B');
      check(
        'custom roots isolate spoofed same-id instances',
        tenantA.getString('tenant-secret') == 'A' &&
            tenantB.getString('tenant-secret') == 'B',
      );
    } finally {
      tenantA.close();
      tenantB.close();
      deleteMMKV(spoofedId, path: '${root.path}/tenant-a');
      deleteMMKV(spoofedId, path: '${root.path}/tenant-b');
    }

    final readOnly = MMKV(
      id: 'readonly-${DateTime.now().microsecondsSinceEpoch}',
      path: root.path,
      readOnly: true,
    );
    try {
      expectMMKVError('read-only storage rejects hostile writes', () {
        readOnly.setString("' OR 1=1 --", 'blocked');
      }, code: -3);
      check('read-only remove is harmless', !readOnly.remove('missing'));
    } finally {
      readOnly.close();
    }

    final sharedId =
        'delete-while-open-${DateTime.now().microsecondsSinceEpoch}';
    final first = MMKV(id: sharedId, path: root.path);
    final second = MMKV(id: sharedId, path: root.path);
    first.setString('before-delete', 'value');
    check(
      'shared handles see the same value',
      second.getString('before-delete') == 'value',
    );
    check(
      'deleting an open instance is reported',
      deleteMMKV(sharedId, path: root.path),
    );
    expectMMKVError(
      'stale sibling handle fails closed after deletion',
      () => second.getString('before-delete'),
    );
    first.close();
    second.close();
    final reopened = MMKV(id: sharedId, path: root.path);
    try {
      reopened.setString('after-delete', 'fresh');
      check(
        'reopens cleanly after deleting an open instance',
        reopened.getString('after-delete') == 'fresh',
      );
    } finally {
      reopened.close();
      deleteMMKV(sharedId, path: root.path);
    }

    final churnPayload = Uint8List.fromList(List<int>.filled(16384, 0x5a));
    for (var index = 0; index < 64; index++) {
      final id = 'churn-$index-${DateTime.now().microsecondsSinceEpoch}';
      final item = MMKV(id: id, path: root.path);
      item.setBuffer('payload', churnPayload);
      item.clearMemoryCache();
      item.close();
      if (!deleteMMKV(id, path: root.path) || existsMMKV(id, path: root.path)) {
        throw StateError('native create/close cycle left storage $id behind');
      }
    }
    check('64 create/write/clear/close cycles complete', true);

    return MMKVSecurityReport(passed: true, passedChecks: passedChecks);
  } catch (error, stack) {
    print('[MMKV_SECURITY] FAIL $error\n$stack');
    return MMKVSecurityReport(
      passed: false,
      passedChecks: passedChecks,
      failure: '$error',
    );
  } finally {
    if (root != null && await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

String _randomAscii(Random random, int length) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789-_';
  return String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    ),
  );
}

String _describe(Object value) => value
    .toString()
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\u0000', r'\0');

bool _same(Uint8List? actual, List<int> expected) {
  if (actual == null || actual.length != expected.length) return false;
  for (var index = 0; index < expected.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}
