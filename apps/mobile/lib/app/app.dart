import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'di/injector.dart';
import 'router/app_router.dart';

/// Root widget: app-wide BLoCs, theme and router. No pages here.
class DashuriApp extends StatefulWidget {
  const DashuriApp({super.key});

  @override
  State<DashuriApp> createState() => _DashuriAppState();
}

class _DashuriAppState extends State<DashuriApp> {
  late final SessionCubit _session = sl<SessionCubit>();
  late final GoRouter _router = buildRouter(session: _session);

  @override
  void initState() {
    super.initState();
    _session.start();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _session,
    child: MaterialApp.router(
      title: 'Dashuri',
      theme: DashuriTheme.light(),
      darkTheme: DashuriTheme.dark(),
      routerConfig: _router,
    ),
  );
}
