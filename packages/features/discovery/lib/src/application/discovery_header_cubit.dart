import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/discovery_home.dart';
import '../domain/usecases/get_discovery_home.dart';
import '../domain/usecases/watch_balance_changes.dart';

final class DiscoveryHeaderState extends Equatable {
  const DiscoveryHeaderState({
    this.home = const DiscoveryHome(),
    this.loading = true,
    this.freeCallDismissed = false,
  });

  final DiscoveryHome home;
  final bool loading;
  final bool freeCallDismissed;

  bool get showFreeCall => home.freeCallAvailable && !freeCallDismissed;

  @override
  List<Object?> get props => [home, loading, freeCallDismissed];
}

/// C01/C02 header: greeting, balance pill, "Online now · N" and the Free
/// Call Card banner (hidden on iOS, dismissible for this session).
// Not final: page tests mock it.
class DiscoveryHeaderCubit extends Cubit<DiscoveryHeaderState> {
  DiscoveryHeaderCubit(
    this._getHome, {
    required this.freeCallSupported,
    WatchBalanceChanges? watchBalance,
  }) : _watchBalance = watchBalance,
       super(const DiscoveryHeaderState());

  final GetDiscoveryHome _getHome;
  final WatchBalanceChanges? _watchBalance;
  final bool freeCallSupported;
  StreamSubscription<void>? _balanceChanges;

  /// Loads the header. The page lives in an IndexedStack shell, so it is
  /// built once; after the first load it re-reads on every `wallet.updated`
  /// hint (purchase, call settlement, gift, refund), or the balance pill
  /// would keep showing the old number until a pull-to-refresh.
  Future<void> load() async {
    _balanceChanges ??= _watchBalance
        ?.call(const NoInput())
        .listen((_) => unawaited(load()));
    final result = await _getHome(freeCallSupported);
    if (isClosed) return;
    if (result case Success(:final value)) {
      emit(
        DiscoveryHeaderState(
          home: value,
          loading: false,
          freeCallDismissed: state.freeCallDismissed,
        ),
      );
    } else {
      emit(
        DiscoveryHeaderState(
          home: state.home,
          loading: false,
          freeCallDismissed: state.freeCallDismissed,
        ),
      );
    }
  }

  void dismissFreeCall() => emit(
    DiscoveryHeaderState(
      home: state.home,
      loading: state.loading,
      freeCallDismissed: true,
    ),
  );

  @override
  Future<void> close() async {
    await _balanceChanges?.cancel();
    return super.close();
  }
}
