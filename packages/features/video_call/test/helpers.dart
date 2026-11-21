import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const phone = Size(360, 640);
const tablet = Size(1024, 768);
const sizes = {'phone': phone, 'tablet': tablet};

/// Pumps [page] at [size] inside a router; unknown routes render
/// `route:<uri>` so navigation can be asserted.
Future<void> pumpPage(WidgetTester t, Widget page, {Size size = phone}) async {
  DashuriText.useGoogleFonts = false;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/:a',
        builder: _echo,
        routes: [
          GoRoute(
            path: ':b',
            builder: _echo,
            routes: [GoRoute(path: ':c', builder: _echo)],
          ),
        ],
      ),
    ],
    errorBuilder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(theme: DashuriTheme.light(), routerConfig: router),
  );
  await t.pump();
}

final class FakeViews implements VideoViewFactory {
  const FakeViews();

  @override
  Widget localPreview({Widget? placeholder}) =>
      const ColoredBox(color: Colors.blue, child: Text('local-video'));

  @override
  Widget remoteVideo({Widget? placeholder}) =>
      const ColoredBox(color: Colors.green, child: Text('remote-video'));
}

CallSession session({
  CallPhase phase = CallPhase.active,
  CallRole role = CallRole.caller,
  bool free = false,
  DateTime? startedAt,
  DateTime? moderationEnds,
  String? endReason,
  int? beans,
  int billed = 0,
  int charged = 0,
}) => CallSession(
  callId: 'c1',
  role: role,
  peerUserId: 'h1',
  phase: phase,
  ratePerMinute: 2400,
  billedSeconds: billed,
  diamondsCharged: charged,
  isFreeCall: free,
  endReason: endReason,
  peer: const CallPeer(userId: 'h1', displayName: 'Ananya'),
  startedAt: startedAt,
  moderationWindowEndsAt: moderationEnds,
  beansEarned: beans,
);

Widget _echo(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('route:${s.uri}'));
