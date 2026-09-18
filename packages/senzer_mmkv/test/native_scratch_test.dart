import 'dart:convert';

import 'package:senzer_mmkv/src/native_scratch.dart';
import 'package:test/test.dart';

void main() {
  test('writes UTF-8 without changing Unicode encoding', () {
    final scratch = NativeByteScratch(initialCapacity: 1);
    addTearDown(scratch.dispose);

    final value = 'ascii café 🐎';
    final length = scratch.writeUtf8(value);

    expect(scratch.view(length), orderedEquals(utf8.encode(value)));
  });

  test('grows and copies byte input', () {
    final scratch = NativeByteScratch(initialCapacity: 1);
    addTearDown(scratch.dispose);
    final input = List<int>.generate(257, (index) => index & 0xff);

    scratch.writeBytes(input);

    expect(scratch.view(input.length), orderedEquals(input));
    expect(scratch.capacity, greaterThanOrEqualTo(input.length));
  });
}
