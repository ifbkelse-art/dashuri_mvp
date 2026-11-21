import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/account_status.dart';
import '../domain/usecases/get_account_status.dart';
import '../domain/usecases/watch_session.dart';

part 'session_state.dart';

/// App-wide session state. Provided once above the router; the route guard
/// reads it to decide redirects through the onboarding flow (FL01).
final class SessionCubit extends Cubit<SessionState>
    implements AccountStatusRefresher {
  SessionCubit(this._watchSession, this._getAccountStatus)
    : super(const SessionUnknown());

  final WatchSession _watchSession;
  final GetAccountStatus _getAccountStatus;
  StreamSubscription<AuthSession?>? _subscription;

  void start() {
    _subscription ??= _watchSession(const NoInput()).listen(_onSession);
  }

  /// Re-reads `GET /v1/me` (after an onboarding step or a retry).
  Future<void> refreshAccount() async {
    if (state case SessionSignedIn(:final session)) await _onSession(session);
  }

  @override
  Future<void> refreshAccountStatus() => refreshAccount();

  /// Applies an AccountStatus returned by an onboarding endpoint
  /// (e.g. POST /v1/me/rules-acceptance) without another round trip.
  void applyAccount(AccountStatus account) {
    if (state case SessionSignedIn(:final session)) {
      emit(SessionSignedIn(session: session, account: account));
    }
  }

  Future<void> _onSession(AuthSession? session) async {
    if (session == null) return emit(const SessionSignedOut());
    final result = await _getAccountStatus(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => SessionSignedIn(
        session: session,
        account: value,
      ),
      Err(:final failure) => SessionSignedIn(
        session: session,
        account: null,
        accountFailure: failure,
      ),
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
