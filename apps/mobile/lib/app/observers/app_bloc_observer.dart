import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';

/// Logs BLoC errors centrally. State changes are not logged (they may hold
/// personal data such as messages or balances).
final class AppBlocObserver extends BlocObserver {
  AppBlocObserver(this._logger);

  final AppLogger _logger;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.error(
      'BLoC error in ${bloc.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
