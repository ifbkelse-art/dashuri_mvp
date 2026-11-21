/// Who can start a chat with me (S04, API `MessagingPrivacy`).
enum WhoCanMessage {
  everyone('everyone', 'Everyone', 'Anyone on Dashuri can send you a message.'),
  pastCallPartners(
    'past_call_partners',
    "People I've called",
    "Only people you've had a video call with.",
  );

  const WhoCanMessage(this.wire, this.label, this.description);

  final String wire;
  final String label;
  final String description;

  static WhoCanMessage fromWire(String value) => WhoCanMessage.values
      .firstWhere((w) => w.wire == value, orElse: () => WhoCanMessage.everyone);
}
