import 'package:senzer_mmkv/src/listener_registry.dart';
import 'package:test/test.dart';

void main() {
  test('notifies listeners registered by sibling MMKV handles', () {
    const scope = 'listener-registry-same-storage';
    final firstEvents = <String>[];
    final secondEvents = <String>[];
    final first = MMKVListenerRegistry.add(scope, firstEvents.add);
    final second = MMKVListenerRegistry.add(scope, secondEvents.add);

    MMKVListenerRegistry.notify(scope, 'changed');
    expect(firstEvents, <String>['changed']);
    expect(secondEvents, <String>['changed']);

    MMKVListenerRegistry.remove(first);
    MMKVListenerRegistry.notify(scope, 'changed-again');
    expect(firstEvents, <String>['changed']);
    expect(secondEvents, <String>['changed', 'changed-again']);

    MMKVListenerRegistry.remove(second);
  });

  test('keeps custom MMKV roots isolated', () {
    final firstEvents = <String>[];
    final secondEvents = <String>[];
    final firstScope = MMKVListenerRegistry.scopeFor(
      id: 'shared-id',
      path: '/one',
    );
    final secondScope = MMKVListenerRegistry.scopeFor(
      id: 'shared-id',
      path: '/two',
    );
    final first = MMKVListenerRegistry.add(firstScope, firstEvents.add);
    final second = MMKVListenerRegistry.add(secondScope, secondEvents.add);

    MMKVListenerRegistry.notify(firstScope, 'only-first');
    expect(firstEvents, <String>['only-first']);
    expect(secondEvents, isEmpty);

    MMKVListenerRegistry.remove(first);
    MMKVListenerRegistry.remove(second);
  });

  test('reports hasListenersForScope correctly', () {
    const scope = 'scope-query-test';
    expect(MMKVListenerRegistry.hasListenersForScope(scope), isFalse);

    final registration = MMKVListenerRegistry.add(scope, (_) {});
    expect(MMKVListenerRegistry.hasListenersForScope(scope), isTrue);
    expect(MMKVListenerRegistry.hasListenersForScope('unrelated-scope'), isFalse);

    MMKVListenerRegistry.remove(registration);
    expect(MMKVListenerRegistry.hasListenersForScope(scope), isFalse);
  });
}
