import 'package:dashuri_core/dashuri_core.dart';
import 'package:test/test.dart';

void main() {
  test('every failure has plain-language copy', () {
    const failures = <Failure>[
      NetworkFailure(),
      UnauthenticatedFailure(),
      ForbiddenFailure(code: 'x'),
      NotFoundFailure(),
      ConflictFailure(code: 'x'),
      ValidationFailure(),
      BusinessRuleFailure(code: 'x'),
      RateLimitedFailure(),
      ServerFailure(),
      PlatformFailure(code: 'x'),
      UnexpectedFailure(),
    ];
    for (final f in failures) {
      expect(failureMessage(f), isNotEmpty);
      expect(failureMessage(f), isNot(contains('null')));
    }
  });

  test('backend_not_configured explains the missing config', () {
    expect(
      failureMessage(const PlatformFailure(code: 'backend_not_configured')),
      contains('no backend configured'),
    );
  });

  test('AppConfig.supportEmail is optional', () {
    final c = AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: Uri.parse('https://api'),
      supabaseUrl: Uri.parse('https://sb'),
      supabasePublishableKey: 'k',
    );
    expect(c.supportEmail, isEmpty);
    expect(c.validate(), isEmpty);
  });
}
