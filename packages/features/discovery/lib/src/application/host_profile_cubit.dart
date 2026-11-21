import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/usecases/get_host_profile.dart';

sealed class HostProfileState extends Equatable {
  const HostProfileState();

  @override
  List<Object?> get props => [];
}

final class HostProfileLoading extends HostProfileState {
  const HostProfileLoading();
}

final class HostProfileFailed extends HostProfileState {
  const HostProfileFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class HostProfileLoaded extends HostProfileState {
  const HostProfileLoaded(this.view);

  final HostProfileView view;

  /// "≈ ₹x/min" in paise, or null when the server sent no basis (D-07).
  int? get approxPaisePerMinute {
    final milli = view.approxPaisePerDiamondMilli;
    return milli == null
        ? null
        : (view.profile.card.ratePerMinute * milli / 1000).round();
  }

  /// Talk-time hint = balance ÷ rate (display only).
  int? get talkTimeSeconds {
    final b = view.balance, rate = view.profile.card.ratePerMinute;
    return b == null || rate <= 0 ? null : b * 60 ~/ rate;
  }

  @override
  List<Object?> get props => [view];
}

/// C07–C09 host profile.
// Not final: page tests mock it.
class HostProfileCubit extends Cubit<HostProfileState> {
  HostProfileCubit(this._get) : super(const HostProfileLoading());

  final GetHostProfile _get;

  Future<void> load(String userId) async {
    emit(const HostProfileLoading());
    final result = await _get(userId);
    emit(switch (result) {
      Success(:final value) => HostProfileLoaded(value),
      Err(:final failure) => HostProfileFailed(failure),
    });
  }
}
