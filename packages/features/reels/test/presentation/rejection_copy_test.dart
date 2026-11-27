import 'package:feature_reels/src/presentation/pages/creator_profile_page.dart'
    show rejectionMessage;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression (2026-11-27): processing failures (a too-large or unreadable
  // file) were shown as "It does not meet our community rules", which tells
  // a host they broke a rule when the file simply could not be processed.
  const generic = 'It does not meet our community rules.';
  const processingCodes = [
    'file_too_large',
    'invalid_media',
    'unsupported_format',
    'no_video_stream',
    'resolution_too_low',
    'upload_missing',
    'upload_expired',
    'processing_failed',
    'duration_out_of_range',
  ];

  for (final code in processingCodes) {
    test('$code has its own plain-language reason', () {
      final m = rejectionMessage(code);
      expect(m, isNot(generic));
      expect(m.toLowerCase(), isNot(contains('rules')));
    });
  }

  test('moderation codes keep their reasons; unknown codes stay generic', () {
    expect(rejectionMessage('sexual_content'), contains('nudity'));
    expect(rejectionMessage('something_new'), generic);
    expect(rejectionMessage(null), generic);
  });
}
