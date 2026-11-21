import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/account_status.dart';
import '../domain/usecases/get_account_status.dart';
import '../domain/usecases/watch_session.dart';

part 'session_state.dart';

/// App-wide session state. Provided once above the router; the route guard
/// reads it to decide redirects (signed out → sign-in, not 18+ → age gate).
final class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._watchSession, this._getAccountStatus)
    : super(const SessionUnknown());

  final WatchSession _watchSession;
  final GetAccountStatus _getAccountStatus;
  StreamSubscription<AuthSession?>? _subscription;

  void start() {
    _subscription ??= _watchSession(const NoInput()).listen(_onSession);
  }

  Future<void> refreshAccount() async {
    if (state case SessionSignedIn(:final session)) await _onSession(session);
  }

  Future<void> _onSession(AuthSession? session) async {
    if (session == null) return emit(const SessionSignedOut());
    final result = await _getAccountStatus(const NoInput());
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
