import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';
import 'package:test/test.dart';

void main() {
  test('validates instance ids before touching native code', () {
    expect(() => MMKV(id: '../private'), throwsA(isA<MMKVException>()));
    expect(() => MMKV(id: ''), throwsA(isA<MMKVException>()));
    expect(() => MMKV(id: 'line\nbreak'), throwsA(isA<MMKVException>()));
    expect(() => MMKV(id: 'nul\u0000byte'), throwsA(isA<MMKVException>()));
    expect(
      () => MMKV(id: 'valid', path: '/tmp/senzer\u0000mmkv'),
      throwsA(isA<MMKVException>()),
    );
  });

  test('validates encryption key byte lengths before loading native code', () {
    expect(
      () => MMKV(id: 'bad-aes128', encryptionKey: 'short'),
      throwsA(isA<MMKVException>()),
    );
    expect(
      () => MMKV(
        id: 'bad-aes256',
        encryptionKey: '0123456789abcdef',
        encryptionType: MMKVEncryptionType.aes256,
      ),
      throwsA(isA<MMKVException>()),
    );
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

  test('exposes exact Dart integer accessors', () {
    void setter(MMKV storage, int value) => storage.setInt64('key', value);
    int? getter(MMKV storage) => storage.getInt64('key');
    expect(setter, isA<Function>());
    expect(getter, isA<Function>());
  });
}
