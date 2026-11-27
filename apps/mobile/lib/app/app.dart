import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_host/feature_host.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/injector.dart';
import 'experience/app_experience_controller.dart';
import 'purchases/purchase_recovery_binding.dart';
import 'router/app_router.dart';

/// Root widget: app-wide BLoCs, theme and router. No pages here.
class DashuriApp extends StatefulWidget {
  const DashuriApp({super.key});

  @override
  State<DashuriApp> createState() => _DashuriAppState();
}

class _DashuriAppState extends State<DashuriApp> {
  late final SessionCubit _session = sl<SessionCubit>();
  late final AppExperienceController _experience =
      sl<AppExperienceController>();
  late final GoRouter _router = buildRouter(
    session: _session,
    experience: _experience,
    backendConfigured: backendConfigured,
    reelsEnabled: reelsEnabled,
  );

  /// Re-reads the account when the app returns to the foreground, so changes
  /// made elsewhere (e.g. host approval) apply without a restart. Quiet: a
  /// failure keeps the current account.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      unawaited(_session.refreshAccountQuietly());
      _purchaseRecovery?.onResume();
    },
  );

  /// Finishes Play purchases paid but never verified (e.g. the app was
  /// killed mid-purchase), at sign-in and on every resume.
  late final PurchaseRecoveryBinding? _purchaseRecovery =
      sl.isRegistered<PurchaseRecovery>()
      ? PurchaseRecoveryBinding(sl<PurchaseRecovery>().run)
      : null;

  @override
  void initState() {
    super.initState();
    _experience.bind(_session);
    _purchaseRecovery?.bind(_session.stream, _session.state);
    _session.start();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    unawaited(_purchaseRecovery?.dispose());
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _session,
    child: MaterialApp.router(
      title: 'Dashuri',
      theme: DashuriTheme.light(),
      darkTheme: DashuriTheme.dark(),
      routerConfig: _router,
      // V16: a ringing call for this user opens the incoming-call screen
      // from anywhere in the app.
      builder: (context, child) => IncomingCallWatcher(
        onIncomingCall: (callId) {
          // Host Home learns about the ring BEFORE the call screen opens:
          // an incoming call always comes first.
          if (sl.isRegistered<HostPresenceController>()) {
            sl<HostPresenceController>().notifyIncomingCall(callId);
          }
          unawaited(
            _router.push(
              '${RoutePaths.withParams(RoutePaths.call, {'callId': callId})}?incoming=1',
            ),
          );
        },
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}
