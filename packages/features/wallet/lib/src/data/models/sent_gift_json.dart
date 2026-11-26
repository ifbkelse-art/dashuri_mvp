import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/sent_gift.dart';

SentGift sentGiftFromJson(JsonMap j) => SentGift(
  giftTransactionId: j['gift_transaction_id']! as String,
  giftName: j['gift_name']! as String,
  emoji: (j['emoji'] as String?) ?? '🎁',
  diamondCost: ((j['diamond_cost'] ?? j['diamond_value'])! as num).toInt(),
  recipientName:
      ((j['recipient'] as JsonMap?)?['display_name'] as String?) ?? '',
  callId: j['call_id']! as String,
  sentAt: DateTime.parse(j['sent_at']! as String).toUtc(),
);
