import 'package:equatable/equatable.dart';

/// One gift the host received (GET /v1/host/gifts). Beans are the host's
/// own earnings from the gift (server-computed; on hold for 7 days).
final class ReceivedGift extends Equatable {
  const ReceivedGift({
    required this.giftTransactionId,
    required this.giftName,
    required this.emoji,
    required this.diamondValue,
    required this.senderName,
    required this.sentAt,
    required this.beansEarned,
    required this.onHold,
    required this.releasesAt,
  });

  final String giftTransactionId;
  final String giftName;
  final String emoji;
  final int diamondValue;
  final String senderName;
  final DateTime sentAt;
  final int beansEarned;

  /// Beans still in the 7-day hold (settlement status on_hold).
  final bool onHold;
  final DateTime releasesAt;

  @override
  List<Object?> get props => [giftTransactionId, onHold];
}

/// Host dashboard gift totals.
final class ReceivedGiftSummary extends Equatable {
  const ReceivedGiftSummary({
    required this.totalGifts,
    required this.totalDiamondValue,
    required this.totalBeans,
    required this.todayGifts,
    required this.todayBeans,
  });

  static const empty = ReceivedGiftSummary(
    totalGifts: 0,
    totalDiamondValue: 0,
    totalBeans: 0,
    todayGifts: 0,
    todayBeans: 0,
  );

  final int totalGifts;
  final int totalDiamondValue;
  final int totalBeans;
  final int todayGifts;
  final int todayBeans;

  @override
  List<Object?> get props => [
    totalGifts,
    totalDiamondValue,
    totalBeans,
    todayGifts,
    todayBeans,
  ];
}
