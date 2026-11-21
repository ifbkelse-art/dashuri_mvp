/// Report reasons (API `ReportRequest.category`), in the V11 display order.
enum ReportCategory {
  nudity('nudity', 'Nudity'),
  sexualContent('sexual_content', 'Sexual content or requests'),
  minorSafety('minor_safety', 'Appears to be under 18'),
  harassment('harassment', 'Harassment, threats or hate'),
  spamOrScam('spam_or_scam', 'Asked to pay or talk outside Dashuri'),
  fakeProfile('fake_profile', 'Scam or fake profile'),
  other('other', 'Something else');

  const ReportCategory(this.wire, this.label);

  /// Value sent to the API.
  final String wire;

  /// V11 copy.
  final String label;
}

/// Maximum length of report details (API `maxLength: 1000`).
const reportDetailsMaxLength = 1000;

/// Maximum length of an appeal statement (API `maxLength: 2000`).
const appealStatementMaxLength = 2000;
