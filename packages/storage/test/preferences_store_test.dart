import 'package:dashuri_storage/dashuri_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('write, read and delete round-trip', () async {
    final store = PreferencesStore(SharedPreferencesAsync());
    await store.write('last_tab', 'wallet');
    expect(await store.read('last_tab'), 'wallet');
    await store.delete('last_tab');
    expect(await store.read('last_tab'), isNull);
  });
}
