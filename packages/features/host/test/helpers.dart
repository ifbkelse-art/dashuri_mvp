import 'dart:async';
import 'dart:typed_data';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// UI/UX pass: opt-in audit hook (no effect unless DASHURI_UIUX_* is set).
import '../../../../tool/uiux/audit_hook.dart';

class MockGetHostStatus extends Mock implements GetHostStatus {}

class MockApplyAsHost extends Mock implements ApplyAsHost {}

class MockStartKyc extends Mock implements StartKyc {}

class MockSetAvailability extends Mock implements SetAvailability {}

class MockSetFreeCallOptIn extends Mock implements SetFreeCallOptIn {}

class MockSendHeartbeat extends Mock implements SendHeartbeat {}

class MockSetRate extends Mock implements SetRate {}

class MockGetEarnings extends Mock implements GetEarnings {}

class MockRequestWithdrawal extends Mock implements RequestWithdrawal {}

class MockListWithdrawals extends Mock implements ListWithdrawals {}

class MockGetMyHostProfile extends Mock implements GetMyHostProfile {}

class MockUpdateHostProfile extends Mock implements UpdateHostProfile {}

class MockUploadHostPhoto extends Mock implements UploadHostPhoto {}

class MockListHostCalls extends Mock implements ListHostCalls {}

class MockHostRepository extends Mock implements HostRepository {}

void registerHostFallbacks() {
  registerFallbackValue(const NoInput());
  registerFallbackValue(IdempotencyKey.generate());
  registerFallbackValue(const PageRequest());
  registerFallbackValue(samplePhoto);
  registerFallbackValue((beans: 0, idempotencyKey: IdempotencyKey.generate()));
  registerFallbackValue((
    photo: samplePhoto,
    idempotencyKey: IdempotencyKey.generate(),
  ));
  registerFallbackValue((displayName: '', bio: null, languages: <String>[]));
}

final samplePhoto = PickedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]),
  contentType: 'image/jpeg',
);

const approvedOffline = HostStatus(
  state: HostStates.approved,
  kycState: KycStates.approved,
  isAvailable: false,
  ratePerMinute: 2400,
  minRatePerMinute: 500,
  maxRatePerMinute: 4000,
  freeCallOptIn: true,
  todayEarnedBeans: 69106,
  todayCalls: 6,
);

final approvedOnline = approvedOffline.copyWith(isAvailable: true);

const appliedHost = HostStatus(
  state: HostStates.applied,
  kycState: KycStates.notStarted,
  isAvailable: false,
  ratePerMinute: 500,
  minRatePerMinute: 500,
  maxRatePerMinute: 2000,
  freeCallOptIn: false,
);

const kycPendingHost = HostStatus(
  state: HostStates.kycPending,
  kycState: KycStates.inProgress,
  isAvailable: false,
  ratePerMinute: 500,
  minRatePerMinute: 500,
  maxRatePerMinute: 2000,
  freeCallOptIn: false,
);

const kycRejectedHost = HostStatus(
  state: HostStates.kycPending,
  kycState: KycStates.rejected,
  isAvailable: false,
  ratePerMinute: 500,
  minRatePerMinute: 500,
  maxRatePerMinute: 2000,
  freeCallOptIn: false,
  kycRejectionReason: 'The selfie did not match the ID photo.',
);

const sampleProfile = HostProfile(
  userId: '11111111-1111-1111-1111-111111111111',
  displayName: 'Ananya',
  bio: 'Chai over coffee.',
  languages: ['hi', 'en'],
  photoUrls: [],
  isHost: true,
  level: 4,
);

final sampleEarnings = HostEarnings(
  beansOnHold: 86450,
  beansAvailable: 124300,
  beansPendingPayout: 20000,
  availableInrPaise: 62150,
  nextPayoutDate: DateTime.utc(2026, 11, 23),
);

const lowEarnings = HostEarnings(
  beansOnHold: 42080,
  beansAvailable: 86450,
  beansPendingPayout: 0,
  availableInrPaise: 43225,
  nextPayoutDate: null,
);

final sampleWithdrawal = Withdrawal(
  id: 'w1',
  beans: 124300,
  amountPaise: 62150,
  status: WithdrawalStatuses.requested,
  requestedAt: DateTime.utc(2026, 11, 21, 15, 44),
  paidAt: null,
);

HostCall sampleCall({
  String id = 'c1',
  String phase = 'ended',
  bool free = false,
  int seconds = 760,
  int? beans = 18236,
  DateTime? at,
}) => HostCall(
  callId: id,
  role: 'receiver',
  peerUserId: '22222222-2222-2222-2222-222222222222',
  peerName: 'Arjun',
  peerPhotoUrl: null,
  phase: phase,
  billedSeconds: seconds,
  isFreeCall: free,
  startedAt: at ?? DateTime(2026, 11, 21, 20, 58),
  beansEarned: beans,
  endReason: null,
);

/// A periodic timer driven by the test ("fake clock").
final class FakePeriodicTimer implements Timer {
  FakePeriodicTimer(this.interval, this._onTick);

  final Duration interval;
  final void Function(Timer) _onTick;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    _onTick(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

final class FakeTimers {
  final created = <FakePeriodicTimer>[];

  FakePeriodicTimer? get active => created.where((t) => t.isActive).lastOrNull;

  Timer call(Duration interval, void Function(Timer) onTick) {
    final t = FakePeriodicTimer(interval, onTick);
    created.add(t);
    return t;
  }
}

/// Screen sizes from WORKSTREAM_RULES (phone, foldable, tablet, desktop).
const phone = Size(360, 640);
const tablet = Size(1024, 768);
const testSizes = {
  'phone 360x640': phone,
  'phone 390x844': Size(390, 844),
  'foldable 600x960': Size(600, 960),
  'tablet 1024x768': tablet,
  'desktop 1280x800': Size(1280, 800),
};

const _stubPaths = [
  RoutePaths.splash,
  RoutePaths.hostDashboard,
  RoutePaths.hostCalls,
  RoutePaths.hostEarnings,
  RoutePaths.hostProfileTab,
  RoutePaths.hostOnboarding,
  RoutePaths.hostVerification,
  RoutePaths.hostAgreement,
  RoutePaths.hostProfileSetup,
  RoutePaths.hostRate,
  RoutePaths.hostWithdraw,
  RoutePaths.hostPayoutHistory,
  RoutePaths.hostPayoutMethod,
  RoutePaths.hostSettings,
  RoutePaths.notifications,
  RoutePaths.enforcement,
  RoutePaths.report,
  RoutePaths.hostProfile,
  RoutePaths.privacyMessaging,
  RoutePaths.blockedUsers,
  RoutePaths.notificationSettings,
  RoutePaths.helpSupport,
  RoutePaths.legal,
  RoutePaths.settings,
  RoutePaths.deleteAccount,
  HostPaths.availability,
  HostPaths.beansExplainer,
];

/// Pumps [page] at `/test` inside a router whose other host-relevant paths
/// render `stub:<path>` so navigation can be asserted.
Future<void> pumpHostPage(
  WidgetTester tester,
  Widget page, {
  Size size = phone,
  double textScale = 1,
  bool settle = true,
}) async {
  DashuriText.useGoogleFonts = false;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await uiuxBeforePump(tester);
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => page),
      for (final p in _stubPaths)
        GoRoute(
          path: p,
          builder: (_, state) => Scaffold(body: Text('stub:${state.uri}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: DashuriTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(uiuxScale(textScale))),
        child: child!,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await uiuxAfterPump(tester);
}
