/// Product analytics contract. No implementation is chosen yet.
///
/// Events must carry no personal data, and sending requires the user's
/// analytics consent (DPDP). The settings feature owns that consent.
abstract interface class AnalyticsSink {
  Future<void> track(String event, {Map<String, Object?> properties});
}
