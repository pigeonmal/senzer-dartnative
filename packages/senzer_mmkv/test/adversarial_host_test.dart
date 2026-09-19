import 'dart:convert';
import 'dart:math';

import 'package:senzer_mmkv/src/listener_registry.dart';
import 'package:senzer_mmkv/src/native_scratch.dart';
import 'package:test/test.dart';

void main() {
  test('scratch UTF-8 encoder survives deterministic hostile text corpus', () {
    final scratch = NativeByteScratch(initialCapacity: 1);
    addTearDown(scratch.dispose);

    final corpus = <String>[
      '',
      '\u0000\u0001\u001f\u007f',
      "' OR 1=1; DROP TABLE values; --",
      r'../../etc/passwd $(id) <script>alert(1)</script>',
      'café 😀 汉字 عربى עברית',
      '\uD800\uDC00\uD800\uDC00',
      '\uD800isolated\uDC00',
    ];
    final random = Random(0x5eed);
    for (var index = 0; index < 256; index++) {
      corpus.add(
        String.fromCharCodes(
          List<int>.generate(
            random.nextInt(96),
            (_) => <int>[
              random.nextInt(0x80),
              0x20,
              0x7f,
              0x300,
              0x1f600,
              0xd800,
              0xdc00,
            ][random.nextInt(7)],
          ),
        ),
      );
    }

    for (final value in corpus) {
      final length = scratch.writeUtf8(value);
      expect(scratch.view(length), orderedEquals(utf8.encode(value)));
    }
  });

  test(
    'scratch bounds checks reject invalid views and dispose is idempotent',
    () {
      final scratch = NativeByteScratch(initialCapacity: 4);
      expect(() => scratch.view(-1), throwsRangeError);
      expect(() => scratch.view(5), throwsRangeError);
      scratch.dispose();
      scratch.dispose();
      expect(scratch.pointer.address, 0);
      expect(scratch.capacity, 0);
    },
  );

  test('listener snapshots tolerate reentrant add/remove under churn', () {
    const scope = 'adversarial-listener-scope';
    final events = <String>[];
    final registrations = <MMKVListenerRegistration>[];
    MMKVListenerRegistration? lateRegistration;

    late final MMKVListenerRegistration first;
    first = MMKVListenerRegistry.add(scope, (key) {
      events.add('first:$key');
      MMKVListenerRegistry.remove(first);
      lateRegistration ??= MMKVListenerRegistry.add(scope, (nestedKey) {
        events.add('late:$nestedKey');
      });
    });
    registrations.add(first);
    for (var index = 0; index < 128; index++) {
      registrations.add(
        MMKVListenerRegistry.add(scope, (key) => events.add('$index:$key')),
      );
    }

    MMKVListenerRegistry.notify(scope, 'one');
    expect(events.where((event) => event == 'first:one'), hasLength(1));
    expect(events.where((event) => event == 'late:one'), isEmpty);
    MMKVListenerRegistry.notify(scope, 'two');
    expect(events.where((event) => event == 'late:two'), hasLength(1));

    for (final registration in registrations) {
      MMKVListenerRegistry.remove(registration);
    }
    if (lateRegistration != null) {
      MMKVListenerRegistry.remove(lateRegistration!);
    }
    expect(MMKVListenerRegistry.hasListenersForScope(scope), isFalse);
    expect(MMKVListenerRegistry.hasAnyListeners, isFalse);
  });

  test('listener scopes cannot cross-contaminate path-like identifiers', () {
    final firstEvents = <String>[];
    final secondEvents = <String>[];
    final firstScope = MMKVListenerRegistry.scopeFor(
      id: "a' OR '1'='1",
      path: '/tmp/../one',
    );
    final secondScope = MMKVListenerRegistry.scopeFor(
      id: "a' OR '1'='1",
      path: '/tmp/../two',
    );
    final first = MMKVListenerRegistry.add(firstScope, firstEvents.add);
    final second = MMKVListenerRegistry.add(secondScope, secondEvents.add);

    MMKVListenerRegistry.notify(firstScope, 'first');
    expect(firstEvents, <String>['first']);
    expect(secondEvents, isEmpty);

    MMKVListenerRegistry.remove(first);
    MMKVListenerRegistry.remove(second);
  });
}
