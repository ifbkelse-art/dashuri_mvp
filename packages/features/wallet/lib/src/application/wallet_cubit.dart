import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/wallet_summary.dart';
import '../domain/usecases/get_wallet_summary.dart';

part 'wallet_state.dart';

/// Loads WalletSummary for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._getWalletSummary) : super(const WalletStateInitial());

  final GetWalletSummary _getWalletSummary;

  Future<void> load() async {
    emit(const WalletStateLoading());
    final result = await _getWalletSummary(const NoInput());
    emit(switch (result) {
      Success(:final value) => WalletStateLoaded(value),
      Err(:final failure) => WalletStateFailed(failure),
    });
  }
}
