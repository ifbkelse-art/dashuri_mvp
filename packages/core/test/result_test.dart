import 'package:dashuri_core/dashuri_core.dart';
import 'package:test/test.dart';

void main() {
  test('map transforms success and passes failure through', () {
    const Result<int> ok = Success(2);
    const Result<int> bad = Err(NotFoundFailure());
    expect(
      ok.map((v) => v * 2).fold(onSuccess: (v) => v, onFailure: (_) => -1),
      4,
    );
    expect(
      bad.map((v) => v * 2).fold(onSuccess: (v) => v, onFailure: (f) => f.code),
      'not_found',
    );
  });

  test('currency units are distinct types over int', () {
    const d = Diamonds(16670);
    const b = Beans(10000);
    expect(d.value, 16670);
    expect(b.value, 10000);
  });

  test('page request builds query', () {
    expect(const PageRequest(cursor: 'abc', limit: 10).toQuery(), {
      'limit': '10',
      'cursor': 'abc',
    });
  });

  test('config validation reports missing values', () {
    final config = AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: Uri.parse(''),
      supabaseUrl: Uri.parse('https://x.supabase.co'),
      supabasePublishableKey: '',
    );
    expect(config.validate(), [
      'DASHURI_API_BASE_URL',
      'DASHURI_SUPABASE_PUBLISHABLE_KEY',
    ]);
  });
}
