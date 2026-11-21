/// Legal documents shown in S08. ALL TEXT IS A DRAFT pending legal review
/// (decision D-12); it must be replaced by reviewed copy before launch.
final class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.sections,
  });

  final String id;
  final String title;

  /// (heading, body) pairs.
  final List<(String, String)> sections;
}

const legalDraftNotice = 'Draft — pending legal review';

const legalDocuments = <LegalDocument>[
  LegalDocument(
    id: 'terms',
    title: 'Terms of Service',
    sections: [
      (
        'Who can use Dashuri',
        'Dashuri is only for adults aged 18 or older in India. You need one '
            'verified mobile number per account.',
      ),
      (
        'Diamonds',
        'Diamonds are a virtual currency used for video calls. They have no '
            'cash value, cannot be transferred and are not refundable except '
            'where the law requires.',
      ),
      (
        'Calls',
        'Calls are billed per minute at the rate shown before the call, '
            'measured by our servers. Calls that never connect are not '
            'charged.',
      ),
      (
        'Conduct',
        'You must follow the Community Guidelines. We may remove content, '
            'end calls or suspend accounts that break them.',
      ),
      (
        'Ending your account',
        'You can delete your account in Settings. Unused Diamonds are lost '
            'when an account is deleted.',
      ),
    ],
  ),
  LegalDocument(
    id: 'privacy',
    title: 'Privacy Policy',
    sections: [
      (
        'What we collect',
        'Your phone number, profile (name, photo, optional city), date of '
            'birth for age checks, purchases, call records (not recordings) '
            'and messages.',
      ),
      (
        'Location',
        'If you choose "Use my location", your approximate position is used '
            'once to find the nearest city. We never store your coordinates.',
      ),
      (
        'Safety checks',
        'During the first minutes of a call, still frames may be checked '
            'automatically for nudity. Frames linked to a report are kept for '
            'review.',
      ),
      (
        'Your rights',
        'You can download a copy of your data, change your consents and '
            'delete your account from Settings.',
      ),
    ],
  ),
  LegalDocument(
    id: 'community',
    title: 'Community Guidelines',
    sections: [
      ('Be kind and respectful', 'No harassment, threats or hate.'),
      (
        'No nudity or sexual content',
        'Calls are checked for safety. Breaking this rule leads to removal.',
      ),
      (
        'Keep it on Dashuri',
        "Don't share phone numbers, social handles or payment details.",
      ),
      (
        'Adults only, always',
        'Report anyone who seems under 18. We act on every report.',
      ),
    ],
  ),
  LegalDocument(
    id: 'child_safety',
    title: 'Child Safety Standards',
    sections: [
      (
        'Zero tolerance',
        'Dashuri prohibits any child sexual abuse material and any contact '
            'with minors. Accounts that break this rule are removed and '
            'reported to the authorities.',
      ),
      (
        'Age checks',
        'Every user declares their date of birth; hosts are verified with ID. '
            'Under-18 declarations are refused.',
      ),
      (
        'Reporting',
        'Use "Appears to be under 18" in any report. These reports are '
            'reviewed first.',
      ),
    ],
  ),
  LegalDocument(
    id: 'refunds',
    title: 'Diamonds & refunds policy',
    sections: [
      (
        'Purchases',
        'Diamonds are added only after the payment is confirmed by Google '
            'Play or our payment provider.',
      ),
      (
        'Failed calls',
        'If a call never connects, any reserved Diamonds are returned '
            'automatically.',
      ),
      (
        'Refunds',
        'Refund requests for purchases follow the store or payment '
            "provider's process. Contact support with your transaction "
            'details.',
      ),
    ],
  ),
  LegalDocument(
    id: 'grievance',
    title: 'Grievance Officer',
    sections: [
      (
        'Grievance redressal',
        'Under the Information Technology (Intermediary Guidelines and '
            'Digital Media Ethics Code) Rules, 2021, you can raise a '
            'complaint with our Grievance Officer. Complaints are '
            'acknowledged within 24 hours and resolved within 15 days.',
      ),
      (
        'Grievance Officer',
        'The Grievance Officer’s name and contact details will be published '
            'here before launch. Until then, use Help & support › Raise a '
            'complaint, which reaches the same team.',
      ),
    ],
  ),
];

LegalDocument? legalDocumentById(String? id) =>
    legalDocuments.where((d) => d.id == id).firstOrNull;
