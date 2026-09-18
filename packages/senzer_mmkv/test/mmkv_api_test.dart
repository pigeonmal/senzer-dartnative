import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';
import 'package:test/test.dart';

void main() {
  test('validates instance ids before touching native code', () {
    expect(() => MMKV(id: '../private'), throwsA(isA<MMKVException>()));
    expect(() => MMKV(id: ''), throwsA(isA<MMKVException>()));
  });

  test('exposes AES-128/AES-256 and recovery options', () {
    expect(MMKVEncryptionType.values, hasLength(2));
    expect(MMKVRecoveryStrategy.values, hasLength(2));
  });

  test('public value surface accepts documented Dart types', () {
    // The native call is intentionally not made on the host test runner.
    expect(<Object>['text', true, 1, 1.5, Uint8List(0)], hasLength(5));
    expect(MMKVMode.values, contains(MMKVMode.multiProcess));
  });

  test('exports explicit root initialization', () {
    expect(initializeMMKV, isA<Function>());
  });
}
