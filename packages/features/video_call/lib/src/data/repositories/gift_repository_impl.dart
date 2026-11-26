import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/gift.dart';
import '../../domain/repositories/gift_repository.dart';
import '../datasources/gift_remote_data_source.dart';
import '../models/gift_json.dart';

final class GiftRepositoryImpl implements GiftRepository {
  const GiftRepositoryImpl(this._remote, this._realtime);

  final GiftRemoteDataSource _remote;
  final RealtimeGateway _realtime;

  @override
  Future<Result<List<Gift>>> catalogue() => _remote.catalogue();

  @override
  Future<Result<GiftReceipt>> send({
    required String callId,
    required String giftId,
    required String recipientUserId,
    required IdempotencyKey idempotencyKey,
  }) => _remote.send(callId, giftId, recipientUserId, idempotencyKey);

  @override
  Future<Result<List<GiftEvent>>> callGifts(String callId) =>
      _remote.callGifts(callId);

  @override
  Stream<GiftEvent> watchCallGifts(String callId) => _realtime
      .subscribe('call:$callId')
      .where((e) => e.type == 'call.gift')
      .map(_safe)
      .where((e) => e != null && e.callId == callId)
      .cast<GiftEvent>();

  @override
  Future<Result<int>> availableDiamonds() async =>
      switch (await _remote.wallet()) {
        Success(:final value) when value['available_diamonds'] is num =>
          Success((value['available_diamonds']! as num).toInt()),
        Success() => const Err(
          UnexpectedFailure(message: 'available_diamonds missing'),
        ),
        Err(:final failure) => Err(failure),
      };

  /// A malformed realtime payload is a hint lost, not a crash.
  static GiftEvent? _safe(RealtimeEvent e) {
    try {
      return giftEventFromJson(e.payload);
    } on Object {
      return null;
    }
  }
}
