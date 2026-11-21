part of 'session_cubit.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Startup, before the first session event.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

final class SessionSignedIn extends SessionState {
  const SessionSignedIn({
    required this.session,
    required this.account,
    this.accountFailure,
  });

  final AuthSession session;

  /// Null if the account status could not be loaded; treat as not eligible.
  final AccountStatus? account;
  final Failure? accountFailure;

  bool get ageEligible => account?.ageEligible ?? false;

  @override
  List<Object?> get props => [session, account, accountFailure];
}
