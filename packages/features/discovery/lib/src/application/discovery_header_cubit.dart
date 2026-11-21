import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/discovery_home.dart';
import '../domain/usecases/get_discovery_home.dart';

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
  DiscoveryHeaderCubit(this._getHome, {required this.freeCallSupported})
    : super(const DiscoveryHeaderState());

  final GetDiscoveryHome _getHome;
  final bool freeCallSupported;

  Future<void> load() async {
    final result = await _getHome(freeCallSupported);
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
}
