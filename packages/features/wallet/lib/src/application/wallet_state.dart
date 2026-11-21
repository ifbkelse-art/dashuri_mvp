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
  const WalletStateLoaded({
    required this.summary,
    this.recent = const [],
    this.isHost = false,
    this.recentFailed = false,
    this.refreshing = false,
  });

  final WalletSummary summary;
  final List<WalletEntry> recent;
  final bool isHost;

  /// Balances loaded but recent activity did not.
  final bool recentFailed;
  final bool refreshing;

  WalletStateLoaded copyWith({bool? refreshing}) => WalletStateLoaded(
    summary: summary,
    recent: recent,
    isHost: isHost,
    recentFailed: recentFailed,
    refreshing: refreshing ?? this.refreshing,
  );

  @override
  List<Object?> get props => [
    summary,
    recent,
    isHost,
    recentFailed,
    refreshing,
  ];
}

final class WalletStateFailed extends WalletState {
  const WalletStateFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
