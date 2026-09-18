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
}
