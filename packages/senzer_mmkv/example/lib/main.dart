import 'dart:typed_data';

import 'package:senzer_mmkv/senzer_mmkv.dart';

void main() {
  // In a DartNative app this is normally generated and called before runApp.
  SenzerMMKVBindings.loadSymbols();
  final storage = createMMKV(id: 'example');
  storage.set('message', 'hello from native C++');
  storage.set('count', (storage.getNumber('count') ?? 0) + 1);
  storage.set('enabled', true);
  storage.set('payload', Uint8List.fromList(<int>[1, 2, 3]));
  print(storage.getAllKeys());
  print(storage.getString('message'));
  storage.close();
}
