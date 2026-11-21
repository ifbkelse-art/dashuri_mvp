import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/wallet_entry.dart';
import '../domain/entities/wallet_summary.dart';
import '../domain/usecases/get_is_host.dart';
import '../domain/usecases/get_wallet_summary.dart';
import '../domain/usecases/list_wallet_entries.dart';
import '../domain/usecases/watch_wallet_updates.dart';

part 'wallet_state.dart';

/// W01 wallet overview: balances, host flag and recent activity.
/// Refreshes silently on `wallet.updated` realtime hints.
// Not final: page tests mock cubits.
class WalletCubit extends Cubit<WalletState> {
  WalletCubit(
    this._getWalletSummary,
    this._listEntries,
    this._getIsHost,
    this._watchUpdates,
  ) : super(const WalletStateInitial());

  final GetWalletSummary _getWalletSummary;
  final ListWalletEntries _listEntries;
  final GetIsHost _getIsHost;
  final WatchWalletUpdates _watchUpdates;
  StreamSubscription<void>? _updates;

  /// Recent activity rows on W01.
  static const recentCount = 5;

  Future<void> load() async {
    emit(const WalletStateLoading());
    await _fetch();
    _updates ??= _watchUpdates(const NoInput()).listen((_) => refresh());
  }

  /// Re-fetches without showing a full-screen spinner (pull to refresh,
  /// realtime hint). Keeps the current data if the refresh fails.
  Future<void> refresh() async {
    final current = state;
    if (current is WalletStateLoaded) {
      emit(current.copyWith(refreshing: true));
    } else if (current is! WalletStateFailed) {
      return;
    }
    await _fetch(previous: current is WalletStateLoaded ? current : null);
  }

  Future<void> _fetch({WalletStateLoaded? previous}) async {
    final results = await (
      _getWalletSummary(const NoInput()),
      _listEntries(const PageRequest(limit: recentCount)),
      _getIsHost(const NoInput()),
    ).wait;
    if (isClosed) return;
    final (summary, entries, host) = results;
    switch (summary) {
      case Err(:final failure):
        emit(
          previous != null
              ? previous.copyWith(refreshing: false)
              : WalletStateFailed(failure),
        );
      case Success(value: final s):
        emit(
          WalletStateLoaded(
            summary: s,
            recent: entries.fold(
              onSuccess: (p) => p.items,
              onFailure: (_) => previous?.recent ?? const [],
            ),
            // Unknown host status falls back to "has any Beans".
            isHost: host.fold(
              onSuccess: (h) => h,
              onFailure: (_) =>
                  s.beansOnHold + s.beansAvailable + s.beansPendingPayout > 0,
            ),
            recentFailed: entries is Err,
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    await _updates?.cancel();
    return super.close();
  }
}
