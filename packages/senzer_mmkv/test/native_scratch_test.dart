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

  test('handles isolated and trailing surrogates with replacement char', () {
    final scratch = NativeByteScratch(initialCapacity: 1);
    addTearDown(scratch.dispose);

    // Trailing high surrogate without low surrogate
    const trailingHigh = 'prefix\uD83D';
    final len1 = scratch.writeUtf8(trailingHigh);
    expect(scratch.view(len1), orderedEquals(utf8.encode('prefix\uFFFD')));

    // High surrogate followed by non-surrogate ASCII
    const highFollowedByAscii = '\uD83Dhello';
    final len2 = scratch.writeUtf8(highFollowedByAscii);
    expect(scratch.view(len2), orderedEquals(utf8.encode('\uFFFDhello')));

    // Isolated low surrogate
    const isolatedLow = 'low\uDC00end';
    final len3 = scratch.writeUtf8(isolatedLow);
    expect(scratch.view(len3), orderedEquals(utf8.encode('low\uFFFDend')));
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
