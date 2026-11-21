import 'dart:math';

/// Random v4 UUID for the `Idempotency-Key` header.
///
/// Create ONE key per user intent (e.g. per tap on "Buy" or "Withdraw") and
/// reuse it for every retry of that intent. The server stores the first
/// response for a key and replays it, so retries never double-charge.
final class IdempotencyKey {
  IdempotencyKey._(this.value);

  factory IdempotencyKey.generate([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return IdempotencyKey._(
      '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}',
    );
  }

  final String value;

  @override
  String toString() => value;
}
