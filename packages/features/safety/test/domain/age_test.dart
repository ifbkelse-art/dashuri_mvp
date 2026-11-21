import 'package:feature_safety/feature_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ageOn counts whole years, birthday-aware', () {
    final today = DateTime(2026, 11, 21);
    expect(ageOn(DateTime(2008, 11, 21), today), 18);
    expect(ageOn(DateTime(2008, 11, 22), today), 17);
    expect(ageOn(DateTime(1998, 4, 14), today), 28);
  });

  test(
    'isoDate pads',
    () => expect(isoDate(DateTime(1998, 4, 4)), '1998-04-04'),
  );

  test('report categories match the API enum', () {
    expect(ReportCategory.values.map((c) => c.wire), [
      'nudity',
      'sexual_content',
      'minor_safety',
      'harassment',
      'spam_or_scam',
      'fake_profile',
      'other',
    ]);
    expect(reportDetailsMaxLength, 1000);
  });
}
