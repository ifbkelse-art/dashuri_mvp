import 'package:equatable/equatable.dart';

/// One gift the customer sent during a call (GET /v1/me/gifts/sent): the
/// Diamonds it cost when sent (never re-priced). The wallet history lists
/// the same spend as a "Gift sent" entry.
final class SentGift extends Equatable {
  const SentGift({
    required this.giftTransactionId,
    required this.giftName,
    required this.emoji,
    required this.diamondCost,
    required this.recipientName,
    required this.callId,
    required this.sentAt,
  });

  final String giftTransactionId;
  final String giftName;
  final String emoji;
  final int diamondCost;
  final String recipientName;
  final String callId;
  final DateTime sentAt;

  @override
  List<Object?> get props => [giftTransactionId];
}
