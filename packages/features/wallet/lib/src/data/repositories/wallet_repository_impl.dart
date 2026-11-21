import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/wallet_summary.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

/// Default [WalletRepository]: delegates to the API and the realtime gateway.
final class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl(
    this._remote, {
    required RealtimeGateway realtime,
    required SessionGateway session,
  }) : _realtime = realtime,
       _session = session;

  final WalletRemoteDataSource _remote;
  final RealtimeGateway _realtime;
  final SessionGateway _session;

  /// Pages scanned by [findWalletEntry] before giving up (5 × 100 entries).
  static const maxScanPages = 5;

  @override
  Future<Result<WalletSummary>> getWalletSummary() =>
      _remote.getWalletSummary();

  @override
  Future<Result<Page<WalletEntry>>> listWalletEntries({
    required PageRequest page,
  }) => _remote.listWalletEntries(page: page);

  @override
  Future<Result<WalletEntry>> findWalletEntry(String entryId) async {
    String? cursor;
    for (var i = 0; i < maxScanPages; i++) {
      final result = await _remote.listWalletEntries(
        page: PageRequest(cursor: cursor, limit: 100),
      );
      switch (result) {
        case Err(:final failure):
          return Err(failure);
        case Success(:final value):
          for (final e in value.items) {
            if (e.id == entryId) return Success(e);
          }
          if (!value.hasMore) return const Err(NotFoundFailure());
          cursor = value.nextCursor;
      }
    }
    return const Err(NotFoundFailure());
  }

  @override
  Future<Result<bool>> isHost() => _remote.isHost();

  @override
  Stream<void> walletUpdates() {
    final userId = _session.currentSession?.userId;
    if (userId == null) return const Stream.empty();
    return _realtime
        .subscribe('user:$userId')
        .where((e) => e.type == 'wallet.updated')
        .map((_) {});
  }
}
