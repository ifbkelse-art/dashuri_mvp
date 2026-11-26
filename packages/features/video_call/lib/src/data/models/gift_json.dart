import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/gift.dart';

int _int(Object? v) => (v! as num).toInt();

Duration _dur(Object? ms) =>
    Duration(milliseconds: ms is num && ms > 0 ? ms.toInt() : 5000);

Gift giftFromJson(JsonMap j) => Gift(
  id: j['id']! as String,
  name: j['name']! as String,
  description: (j['description'] as String?) ?? '',
  emoji: (j['emoji'] as String?) ?? '🎁',
  iconAsset: (j['icon_asset'] as String?) ?? '',
  animationAsset: (j['animation_asset'] as String?) ?? '',
  animationDuration: _dur(j['animation_duration_ms']),
  tier: GiftTier.parse(j['tier'] as String?),
  sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
  diamondPrice: _int(j['diamond_price']),
);

List<Gift> giftCatalogueFromJson(JsonMap j) =>
    (j['items']! as List).cast<JsonMap>().map(giftFromJson).toList()..sort(
      (a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.diamondPrice.compareTo(b.diamondPrice),
    );

GiftEvent giftEventFromJson(JsonMap j) {
  final sender = j['sender']! as JsonMap;
  final recipient = j['recipient']! as JsonMap;
  return GiftEvent(
    giftTransactionId: j['gift_transaction_id']! as String,
    giftId: j['gift_id']! as String,
    giftName: j['gift_name']! as String,
    emoji: (j['emoji'] as String?) ?? '🎁',
    tier: GiftTier.parse(j['tier'] as String?),
    diamondValue: _int(j['diamond_value']),
    senderId: sender['user_id']! as String,
    senderName: (sender['display_name'] as String?) ?? '',
    recipientId: recipient['user_id']! as String,
    recipientName: (recipient['display_name'] as String?) ?? '',
    callId: j['call_id']! as String,
    animationAsset: (j['animation_asset'] as String?) ?? '',
    animationDuration: _dur(j['animation_duration_ms']),
    chatMessageId: j['chat_message_id'] as String?,
    sentAt: DateTime.parse(j['sent_at']! as String).toUtc(),
  );
}

GiftReceipt giftReceiptFromJson(JsonMap j) => GiftReceipt(
  event: giftEventFromJson(j['gift']! as JsonMap),
  availableDiamonds: _int(j['available_diamonds']),
  replayed: j['replayed'] == true,
);

List<GiftEvent> giftEventsFromJson(JsonMap j) =>
    (j['items']! as List).cast<JsonMap>().map(giftEventFromJson).toList();
