import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

final class _FakePicker implements HostPhotoPicker {
  int calls = 0;

  @override
  Future<PickedPhoto?> pickPhoto() async {
    calls++;
    return samplePhoto;
  }
}

void main() {
  setUpAll(registerHostFallbacks);

  group('H01/H02 onboarding', () {
    late MockGetHostStatus getStatus;
    late MockApplyAsHost apply;
    setUp(() {
      getStatus = MockGetHostStatus();
      apply = MockApplyAsHost();
    });

    Widget page() => BlocProvider(
      create: (_) => HostApplicationCubit(getStatus, apply)..load(),
      child: const HostOnboardingPage(),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('intro renders at $name', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(HostStatus.notApplied));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Your time, your terms.'), findsOneWidget);
        expect(find.text('Start application'), findsOneWidget);
      });
    }

    testWidgets('start application posts and opens the agreement', (
      tester,
    ) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(HostStatus.notApplied));
      when(
        () => apply(any()),
      ).thenAnswer((_) async => const Success(appliedHost));
      await pumpHostPage(tester, page(), textScale: 1.3);
      await tester.tap(find.text('Start application'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/agreement'), findsOneWidget);
    });

    testWidgets('closed applications show a message', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(HostStatus.notApplied));
      when(() => apply(any())).thenAnswer(
        (_) async =>
            const Err(BusinessRuleFailure(code: 'host_applications_closed')),
      );
      await pumpHostPage(tester, page());
      await tester.tap(find.text('Start application'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('not accepting new host applications'),
        findsOneWidget,
      );
    });

    testWidgets('applied host sees steps and continues', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(kycPendingHost));
      await pumpHostPage(tester, page(), size: tablet);
      expect(find.text("Let's verify it's really you"), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/verification'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });

  group('H06 agreement', () {
    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('draft marker and gated accept at $name', (tester) async {
        await pumpHostPage(tester, const HostAgreementPage(), size: size);
        expect(
          find.textContaining('Draft — pending legal review'),
          findsOneWidget,
        );
        final button = find.widgetWithText(FilledButton, 'Accept and continue');
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('stub:/host/verification'), findsOneWidget);
      });
    }

    testWidgets('read-only mode has no accept action', (tester) async {
      await pumpHostPage(tester, const HostAgreementPage(readOnly: true));
      expect(find.text('Accept and continue'), findsNothing);
    });
  });

  group('H03–H05, H07, H08 verification', () {
    late MockGetHostStatus getStatus;
    late MockStartKyc startKyc;
    setUp(() {
      getStatus = MockGetHostStatus();
      startKyc = MockStartKyc();
    });

    Widget page({HostModeEnter? enter}) => BlocProvider(
      create: (_) => HostVerificationCubit(getStatus, startKyc)..load(),
      child: HostVerificationPage(hostModeEnter: enter),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('manual verification step at $name', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(appliedHost));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Verify your identity'), findsOneWidget);
        expect(find.text('Manual review'), findsOneWidget);
      });
    }

    testWidgets('requesting verification starts a session then opens H09', (
      tester,
    ) async {
      var calls = 0;
      when(() => getStatus(any())).thenAnswer(
        (_) async => Success(calls++ == 0 ? appliedHost : kycPendingHost),
      );
      when(() => startKyc(any())).thenAnswer(
        (_) async =>
            const Success(KycSession(sessionId: 'kyc_1', redirectUrl: null)),
      );
      await pumpHostPage(tester, page());
      await tester.tap(find.text('Request verification'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/profile-setup?flow=apply'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('H07 under review at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(kycPendingHost));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text("You're almost there"), findsOneWidget);
        expect(
          find.text('Our team will contact you to verify your ID'),
          findsOneWidget,
        );
      });

      testWidgets('H08 attention with reason at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(kycRejectedHost));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Verification needs attention'), findsOneWidget);
        expect(find.textContaining('did not match'), findsOneWidget);
      });

      testWidgets('error at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }

    testWidgets('approved host goes home', (tester) async {
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      await pumpHostPage(tester, page());
      await tester.tap(find.text('Go to host home'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host'), findsOneWidget);
    });

    // UI/UX pass: known bug "host role needs an app restart after approval".
    testWidgets(
      'approved: enters host mode (fresh account) before going home',
      (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Success(approvedOffline));
        final entered = Completer<void>();
        var calls = 0;
        await pumpHostPage(
          tester,
          page(
            enter: HostModeEnter(() {
              calls++;
              return entered.future;
            }),
          ),
        );
        await tester.tap(find.text('Go to host home'));
        await tester.pump();
        expect(calls, 1);
        expect(find.text('stub:/host'), findsNothing); // waits for the refresh
        entered.complete();
        await tester.pumpAndSettle();
        expect(find.text('stub:/host'), findsOneWidget);
      },
    );
  });

  group('H09 profile setup', () {
    late MockGetMyHostProfile getProfile;
    late MockUpdateHostProfile update;
    late MockUploadHostPhoto upload;
    setUp(() {
      getProfile = MockGetMyHostProfile();
      update = MockUpdateHostProfile();
      upload = MockUploadHostPhoto();
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
    });

    Widget page({bool apply = false, HostPhotoPicker? picker}) => BlocProvider(
      create: (_) => HostProfileSetupCubit(getProfile, update, upload)..load(),
      child: HostProfileSetupPage(fromApplication: apply, photoPicker: picker),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('form renders at $name', (tester) async {
        await pumpHostPage(tester, page(apply: true), size: size);
        expect(find.text('Make your profile shine'), findsOneWidget);
        expect(find.text('Hindi'), findsOneWidget);
        expect(
          find.textContaining("isn't available in this version"),
          findsOneWidget,
        );
      });
    }

    testWidgets('saving in the application continues to the rate step', (
      tester,
    ) async {
      when(
        () => update(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
      await pumpHostPage(tester, page(apply: true));
      await tester.tap(find.text('Continue to rate'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/rate?flow=apply'), findsOneWidget);
    });

    testWidgets('validation errors show inline', (tester) async {
      await pumpHostPage(tester, page());
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        ' ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your display name.'), findsOneWidget);
      verifyNever(() => update(any()));
    });

    testWidgets('a picker enables photo upload', (tester) async {
      final picker = _FakePicker();
      when(() => upload(any())).thenAnswer(
        (_) async => Success(
          PhotoUploadTicket(
            photoId: 'p1',
            uploadUrl: Uri.parse('https://s.example/u'),
            expiresAt: DateTime.utc(2026),
          ),
        ),
      );
      await pumpHostPage(tester, page(picker: picker), size: tablet);
      await tester.tap(find.bySemanticsLabel('Add photo'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(find.text('In review'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error at $size', (tester) async {
        when(
          () => getProfile(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });

  group('H10 rate', () {
    late MockGetHostStatus getStatus;
    late MockSetRate setRate;
    setUp(() {
      getStatus = MockGetHostStatus();
      setRate = MockSetRate();
      when(
        () => getStatus(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
    });

    Widget page({bool apply = false}) => BlocProvider(
      create: (_) => HostRateCubit(getStatus, setRate)..load(),
      child: HostRatePage(fromApplication: apply),
    );

    for (final MapEntry(key: name, value: size) in testSizes.entries) {
      testWidgets('rate editor renders at $name', (tester) async {
        await pumpHostPage(tester, page(), size: size);
        expect(find.textContaining(amount('2,400')), findsOneWidget);
        expect(find.text('Your limit 4,000'), findsOneWidget);
        expect(find.textContaining('≈ ₹'), findsWidgets);
      });
    }

    testWidgets('text scale 1.3 on a small phone', (tester) async {
      await pumpHostPage(tester, page(), textScale: 1.3);
      expect(find.text('Save rate'), findsOneWidget);
    });

    testWidgets('server level-cap error is shown', (tester) async {
      when(() => setRate(any())).thenAnswer(
        (_) async =>
            const Err(BusinessRuleFailure(code: 'rate_outside_level_limits')),
      );
      await pumpHostPage(tester, page());
      await tester.tap(find.byTooltip('Raise rate'));
      await tester.pump();
      await tester.tap(find.text('Save rate'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your level allows up to 4,000 Diamonds per minute.'),
        findsOneWidget,
      );
    });

    testWidgets('saving in the application opens the review screen', (
      tester,
    ) async {
      when(
        () => setRate(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      await pumpHostPage(tester, page(apply: true));
      // Before approval: no "Save rate … next call" wording.
      expect(find.text('Save rate'), findsNothing);
      expect(find.textContaining('next call'), findsNothing);
      expect(find.textContaining('once you are approved'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/host/verification'), findsOneWidget);
    });

    for (final size in [phone, tablet]) {
      testWidgets('error at $size', (tester) async {
        when(
          () => getStatus(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await pumpHostPage(tester, page(), size: size);
        expect(find.text('Try again'), findsOneWidget);
      });
    }
  });
}

/// A CurrencyAmount's text: the amount, after its inline glyph.
RegExp amount(String text) => RegExp('^\uFFFC?${RegExp.escape(text)}\$');
