/// Shared value-change listener storage for all handles to the same MMKV file.
///
/// MMKV exposes listeners per storage identifier, rather than per Dart wrapper
/// object. Keeping this registry outside [MMKV] mirrors that behavior while
/// avoiding any native callback or platform-channel work on the write hot path.
typedef MMKVValueChangedCallback = void Function(String key);

final class MMKVListenerRegistration {
  const MMKVListenerRegistration(this.scope, this.id);

  final String scope;
  final int id;
}

final class MMKVListenerRegistry {
  MMKVListenerRegistry._();

  static final Map<String, Map<int, MMKVValueChangedCallback>>
  _listenersByScope = <String, Map<int, MMKVValueChangedCallback>>{};
  static int _nextId = 0;

  /// Lets write-heavy callers skip hashing their scope when no subscription
  /// exists anywhere in the isolate.
  static bool get hasAnyListeners => _listenersByScope.isNotEmpty;

  /// Returns true if any listeners are registered for [scope].
  static bool hasListenersForScope(String scope) {
    final listeners = _listenersByScope[scope];
    return listeners != null && listeners.isNotEmpty;
  }

  /// Produces a stable key for one storage file without conflating custom
  /// roots that happen to use the same MMKV id.
  static String scopeFor({required String id, String? path}) =>
      '${path ?? ''}\u0000$id';

  static MMKVListenerRegistration add(
    String scope,
    MMKVValueChangedCallback listener,
  ) {
    final id = _nextId++;
    (_listenersByScope[scope] ??= <int, MMKVValueChangedCallback>{})[id] =
        listener;
    return MMKVListenerRegistration(scope, id);
  }

  static void remove(MMKVListenerRegistration registration) {
    final listeners = _listenersByScope[registration.scope];
    if (listeners == null) return;
    listeners.remove(registration.id);
    if (listeners.isEmpty) _listenersByScope.remove(registration.scope);
  }

  static void notify(String scope, String key) {
    final listeners = _listenersByScope[scope];
    if (listeners == null) return;
    // Snapshot so callbacks may safely remove or add subscriptions.
    for (final listener in List<MMKVValueChangedCallback>.of(
      listeners.values,
    )) {
      listener(key);
    }
  }
}
