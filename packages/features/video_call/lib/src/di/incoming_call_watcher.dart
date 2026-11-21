import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/incoming_call_cubit.dart';

/// Wrap the app with this: it watches `user:<currentUserId>` for ringing
/// calls where the user is the receiver and calls [onIncomingCall] once per
/// call. The integrator then opens
/// `RoutePaths.call` (callId) with query `incoming=1`.
class IncomingCallWatcher extends StatefulWidget {
  const IncomingCallWatcher({
    required this.child,
    required this.onIncomingCall,
    super.key,
    this.cubit,
  });

  final Widget child;
  final void Function(String callId) onIncomingCall;

  /// For tests; defaults to `GetIt.instance<IncomingCallCubit>()`.
  final IncomingCallCubit? cubit;

  @override
  State<IncomingCallWatcher> createState() => _IncomingCallWatcherState();
}

class _IncomingCallWatcherState extends State<IncomingCallWatcher> {
  late final IncomingCallCubit _cubit =
      (widget.cubit ?? GetIt.instance<IncomingCallCubit>())..start();

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<IncomingCallCubit, IncomingCallState>(
        bloc: _cubit,
        listenWhen: (a, b) => b.sequence != a.sequence && b.callId != null,
        listener: (_, s) => widget.onIncomingCall(s.callId!),
        child: widget.child,
      );
}
