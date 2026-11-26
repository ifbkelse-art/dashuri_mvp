import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/arrival_photo.dart';
import '../../domain/entities/host_gift.dart';

DateTime? _time(Object? v) => v is String ? DateTime.parse(v).toUtc() : null;

ArrivalPhoto arrivalPhotoFromJson(JsonMap j) => ArrivalPhoto(
  photoId: j['photo_id']! as String,
  sessionId: j['session_id']! as String,
  status: ArrivalPhotoStatus.parse(j['status'] as String?),
  capturedAt: _time(j['captured_at']),
  photoUrl: j['photo_url'] as String?,
  reason: j['reason'] as String?,
);

ArrivalUploadTicket arrivalTicketFromJson(JsonMap j) => ArrivalUploadTicket(
  photoId: j['photo_id']! as String,
  sessionId: j['session_id']! as String,
  uploadUrl: Uri.parse(j['upload_url']! as String),
  expiresAt: DateTime.parse(j['expires_at']! as String).toUtc(),
  maxBytes: (j['max_bytes'] as num?)?.toInt() ?? 2 * 1024 * 1024,
);

ReceivedGift receivedGiftFromJson(JsonMap j) => ReceivedGift(
  giftTransactionId: j['gift_transaction_id']! as String,
  giftName: j['gift_name']! as String,
  emoji: (j['emoji'] as String?) ?? '🎁',
  diamondValue: (j['diamond_value']! as num).toInt(),
  senderName: ((j['sender'] as JsonMap?)?['display_name'] as String?) ?? '',
  sentAt: DateTime.parse(j['sent_at']! as String).toUtc(),
  beansEarned: (j['beans_earned']! as num).toInt(),
  onHold: j['settlement_status'] != 'released',
  releasesAt: DateTime.parse(j['releases_at']! as String).toUtc(),
);

ReceivedGiftSummary receivedGiftSummaryFromJson(JsonMap j) =>
    ReceivedGiftSummary(
      totalGifts: (j['total_gifts'] as num?)?.toInt() ?? 0,
      totalDiamondValue: (j['total_diamond_value'] as num?)?.toInt() ?? 0,
      totalBeans: (j['total_beans_earned'] as num?)?.toInt() ?? 0,
      todayGifts: (j['today_gifts'] as num?)?.toInt() ?? 0,
      todayBeans: (j['today_beans_earned'] as num?)?.toInt() ?? 0,
    );
