import 'package:equatable/equatable.dart';

/// Gift rarity. Higher tiers get visually richer celebrations.
enum GiftTier {
  common,
  rare,
  epic,
  legendary,
  mythic;

  static GiftTier parse(String? v) =>
      GiftTier.values.firstWhere((t) => t.name == v, orElse: () => common);
}

/// One catalogue entry. The price is the server's; the client only shows it.
final class Gift extends Equatable {
  const Gift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tier,
    required this.diamondPrice,
    this.description = '',
    this.iconAsset = '',
    this.animationAsset = '',
    this.animationDuration = const Duration(seconds: 5),
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final String iconAsset;
  final String animationAsset;
  final Duration animationDuration;
  final GiftTier tier;
  final int sortOrder;
  final int diamondPrice;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    emoji,
    iconAsset,
    animationAsset,
    animationDuration,
    tier,
    sortOrder,
    diamondPrice,
  ];
}

/// The server's canonical record of one sent gift (`call.gift` realtime
/// payload and call gift history). Public data only: no balances.
final class GiftEvent extends Equatable {
  const GiftEvent({
    required this.giftTransactionId,
    required this.giftId,
    required this.giftName,
    required this.emoji,
    required this.tier,
    required this.diamondValue,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.callId,
    required this.sentAt,
    this.animationAsset = '',
    this.animationDuration = const Duration(seconds: 5),
    this.chatMessageId,
  });

  final String giftTransactionId;
  final String giftId;
  final String giftName;
  final String emoji;
  final GiftTier tier;
  final int diamondValue;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String callId;
  final String animationAsset;
  final Duration animationDuration;
  final String? chatMessageId;
  final DateTime sentAt;

  @override
  List<Object?> get props => [giftTransactionId];
}

/// The sender's receipt for POST /v1/calls/{id}/gifts.
final class GiftReceipt extends Equatable {
  const GiftReceipt({
    required this.event,
    required this.availableDiamonds,
    required this.replayed,
  });

  final GiftEvent event;

  /// The sender's own available Diamonds after the gift (server-computed).
  final int availableDiamonds;

  /// The server returned an earlier result for the same Idempotency-Key.
  final bool replayed;

  @override
  List<Object?> get props => [event, availableDiamonds, replayed];
}
