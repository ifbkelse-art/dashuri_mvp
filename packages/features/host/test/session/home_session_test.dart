import 'dart:typed_data';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

class _Camera extends Mock implements ArrivalCamera {}

class _Submit extends Mock implements SubmitArrivalPhoto {}

class _Current extends Mock implements GetArrivalPhoto {}

class _Remove extends Mock implements RemoveArrivalPhoto {}

class _Profile extends Mock implements GetMyHostProfile {}

class _FreeCall extends Mock implements SetFreeCallOptIn {}

class _Gifts extends Mock implements GetReceivedGifts {}

class _GiftSummary extends Mock implements GetReceivedGiftSummary {}

// A 1×1 JPEG so Image.memory can decode the preview.
final _tinyJpeg = Uint8List.fromList(const [
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
  0x01,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0xFF,
  0xDB,
  0x00,
  0x43,
  0x00,
  0x08,
  0x06,
  0x06,
  0x07,
  0x06,
  0x05,
  0x08,
  0x07,
  0x07,
  0x07,
  0x09,
  0x09,
  0x08,
  0x0A,
  0x0C,
  0x14,
  0x0D,
  0x0C,
  0x0B,
  0x0B,
  0x0C,
  0x19,
  0x12,
  0x13,
  0x0F,
  0x14,
  0x1D,
  0x1A,
  0x1F,
  0x1E,
  0x1D,
  0x1A,
  0x1C,
  0x1C,
  0x20,
  0x24,
  0x2E,
  0x27,
  0x20,
  0x22,
  0x2C,
  0x23,
  0x1C,
  0x1C,
  0x28,
  0x37,
  0x29,
  0x2C,
  0x30,
  0x31,
  0x34,
  0x34,
  0x34,
  0x1F,
  0x27,
  0x39,
  0x3D,
  0x38,
  0x32,
  0x3C,
  0x2E,
  0x33,
  0x34,
  0x32,
  0xFF,
  0xC0,
  0x00,
  0x0B,
  0x08,
  0x00,
  0x01,
  0x00,
  0x01,
  0x01,
  0x01,
  0x11,
  0x00,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x09,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x10,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xFF,
  0xDA,
  0x00,
  0x08,
  0x01,
  0x01,
  0x00,
  0x00,
  0x3F,
  0x00,
  0x2A,
  0x9F,
  0xFF,
  0xD9,
]);

HostStatus _online() => HostStatus(
  state: approvedOffline.state,
  kycState: approvedOffline.kycState,
  isAvailable: true,
  ratePerMinute: 1500,
  minRatePerMinute: 500,
  maxRatePerMinute: 2000,
  freeCallOptIn: false,
  level: 2,
  nextLevelMaxRatePerMinute: 3000,
  onlineSessionId: 's1',
  onlineSince: DateTime.now().toUtc().subtract(const Duration(minutes: 12)),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(
      PickedPhoto(bytes: Uint8List(1), contentType: 'image/jpeg'),
    );
    registerFallbackValue(const PageRequest(limit: 1));
  });

  late MockGetHostStatus status;
  late MockSetAvailability setAvailability;
  late HostPresenceController presence;
  late _Camera camera;
  late _Submit submit;
  late _Current current;
  late _Profile profile;
  late _FreeCall freeCall;

  setUp(() {
    status = MockGetHostStatus();
    setAvailability = MockSetAvailability();
    final heartbeat = MockSendHeartbeat();
    when(() => heartbeat(any())).thenAnswer((_) async => const Success(null));
    presence = HostPresenceController(
      heartbeat,
      timerFactory: FakeTimers().call,
    );
    camera = _Camera();
    submit = _Submit();
    current = _Current();
    profile = _Profile();
    freeCall = _FreeCall();
    when(
      () => profile(any()),
    ).thenAnswer((_) async => const Success(sampleProfile));
    when(() => current(any())).thenAnswer((_) async => const Success(null));
  });
  tearDown(() async {
    await presence.dispose();
  });

  Widget page({
    bool arrival = true,
    bool gifts = false,
    HostSessionStarted start = const HostSessionStarted(),
  }) {
    final giftList = _Gifts();
    when(
      () => giftList(any()),
    ).thenAnswer((_) async => const Success(Page<ReceivedGift>(items: [])));
    final giftSummary = _GiftSummary();
    when(
      () => giftSummary(any()),
    ).thenAnswer((_) async => const Success(ReceivedGiftSummary.empty));
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => HostSessionBloc(
            getStatus: status,
            setAvailability: setAvailability,
            presence: presence,
          )..add(start),
        ),
        BlocProvider(
          create: (_) => HostDashboardCubit(
            status,
            setAvailability: setAvailability,
            setFreeCallOptIn: freeCall,
            getMyProfile: profile,
            presence: presence,
          )..load(),
        ),
        if (arrival)
          BlocProvider(
            create: (_) => ArrivalPhotoCubit(
              camera: camera,
              submit: submit,
              current: current,
              remove: _Remove(),
            ),
          ),
        if (gifts)
          BlocProvider(create: (_) => HostGiftsCubit(giftList, giftSummary)),
      ],
      child: HostDashboardPage(arrivalEnabled: arrival, giftsEnabled: gifts),
    );
  }

  Future<void> pumpFor(WidgetTester t, Duration d) async {
    for (var i = 0; i < d.inMilliseconds ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('go online: arrival prompt, Skip → online without a photo', (
    t,
  ) async {
    when(
      () => status(any()),
    ).thenAnswer((_) async => const Success(approvedOffline));
    when(
      () => setAvailability(true),
    ).thenAnswer((_) async => Success(_online()));
    await pumpHostPage(
      t,
      page(start: const HostSessionStarted(activate: true)),
      settle: false,
    );
    await pumpFor(t, const Duration(seconds: 1));
    expect(find.text('Add an arrival photo?'), findsOneWidget);
    expect(find.textContaining('optional'), findsOneWidget);
    await t.tap(find.text('Skip'));
    await pumpFor(t, const Duration(seconds: 1));
    expect(find.text('Online for 12 min'), findsOneWidget);
    verify(() => setAvailability(true)).called(1);
    verifyNever(() => camera.capture());
    verifyNever(() => submit(any()));
    expect(find.textContaining('Live'), findsNothing);
  });

  testWidgets(
    'capture → preview → Use photo → online → uploaded to the session',
    (t) async {
      when(
        () => status(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      when(
        () => setAvailability(true),
      ).thenAnswer((_) async => Success(_online()));
      when(() => camera.capture()).thenAnswer(
        (_) async => PickedPhoto(bytes: _tinyJpeg, contentType: 'image/jpeg'),
      );
      when(() => submit(any())).thenAnswer(
        (_) async => Success(
          ArrivalPhoto(
            photoId: 'p1',
            sessionId: 's1',
            status: ArrivalPhotoStatus.approved,
            capturedAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 3),
            ),
          ),
        ),
      );
      await pumpHostPage(
        t,
        page(start: const HostSessionStarted(activate: true)),
        size: const Size(390, 844),
        settle: false,
      );
      await pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.text('Capture photo'));
      await pumpFor(t, const Duration(milliseconds: 500));
      expect(find.text('Use this photo?'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      verifyNever(() => setAvailability(any())); // not online before confirming
      await t.tap(find.text('Use photo'));
      await pumpFor(t, const Duration(seconds: 1));
      verify(() => setAvailability(true)).called(1);
      verify(() => submit(any())).called(1);
      expect(find.text('Captured 3 minutes ago'), findsOneWidget);
      expect(find.text('Visible to customers'), findsOneWidget);
    },
  );

  testWidgets('without arrival photos: Go online goes straight online', (
    t,
  ) async {
    when(
      () => status(any()),
    ).thenAnswer((_) async => const Success(approvedOffline));
    when(
      () => setAvailability(true),
    ).thenAnswer((_) async => Success(_online()));
    await pumpHostPage(
      t,
      page(arrival: false, start: const HostSessionStarted(activate: true)),
      settle: false,
    );
    await pumpFor(t, const Duration(seconds: 1));
    expect(find.text('Add an arrival photo?'), findsNothing);
    expect(find.text('Online for 12 min'), findsOneWidget);
  });

  testWidgets('incoming call shows on Host Home at once', (t) async {
    when(() => status(any())).thenAnswer((_) async => Success(_online()));
    await pumpHostPage(
      t,
      page(arrival: false),
      size: const Size(390, 844),
      settle: false,
    );
    await pumpFor(t, const Duration(milliseconds: 500));
    presence.notifyIncomingCall('c1');
    await pumpFor(t, const Duration(milliseconds: 300));
    expect(find.text('Incoming call'), findsOneWidget);
    expect(
      find.text('A customer is calling — opening the call…'),
      findsOneWidget,
    );
    // Going offline is not offered while a call rings.
    final goOffline = t.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Go offline'),
    );
    expect(goOffline.onPressed, isNull);
  });

  testWidgets('after a declined call Host Home says you are still online', (
    t,
  ) async {
    when(() => status(any())).thenAnswer((_) async => Success(_online()));
    await pumpHostPage(
      t,
      page(
        arrival: false,
        start: const HostSessionStarted(after: CallNotice.declined),
      ),
      settle: false,
    );
    await pumpFor(t, const Duration(milliseconds: 500));
    expect(find.text("Call declined. You're still online."), findsOneWidget);
  });

  testWidgets('go offline: session ended with duration', (t) async {
    when(() => status(any())).thenAnswer((_) async => Success(_online()));
    when(
      () => setAvailability(false),
    ).thenAnswer((_) async => const Success(approvedOffline));
    await pumpHostPage(t, page(arrival: false), settle: false);
    await pumpFor(t, const Duration(milliseconds: 500));
    await t.tap(find.text('Go offline'));
    await pumpFor(t, const Duration(milliseconds: 500));
    expect(find.text('Session ended'), findsOneWidget);
    expect(find.textContaining('You were online for 12 min'), findsOneWidget);
    expect(find.text('Go online again'), findsOneWidget);
  });

  for (final MapEntry(key: name, value: size) in testSizes.entries) {
    testWidgets('Host Home lays out at $name with large text', (t) async {
      when(() => status(any())).thenAnswer((_) async => Success(_online()));
      await pumpHostPage(
        t,
        page(gifts: true),
        size: size,
        textScale: 1.3,
        settle: false,
      );
      await pumpFor(t, const Duration(milliseconds: 500));
      expect(find.text("You're online"), findsOneWidget);
      expect(find.text('Arrival photo'), findsOneWidget);
      expect(find.text('Gifts'), findsOneWidget);
      // The waiting room and its games are gone.
      expect(find.text('Waiting room'), findsNothing);
      expect(find.text('Quick trivia'), findsNothing);
      expect(find.text('Open waiting room'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
