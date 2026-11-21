part of 'wallet_cubit.dart';

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

final class WalletStateInitial extends WalletState {
  const WalletStateInitial();
}

final class WalletStateLoading extends WalletState {
  const WalletStateLoading();
}

final class WalletStateLoaded extends WalletState {
  const WalletStateLoaded(this.data);

  final WalletSummary data;

  @override
  List<Object?> get props => [data];
}

final class WalletStateFailed extends WalletState {
  const WalletStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
