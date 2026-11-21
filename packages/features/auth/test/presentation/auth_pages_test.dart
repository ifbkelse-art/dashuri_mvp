import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/pump.dart';

Widget _with<C extends StateStreamableSource<Object?>>(C cubit, Widget child) =>
    BlocProvider<C>.value(value: cubit, child: child);

void main() {
  group('SplashPage (A01)', () {
    testResponsive('shows the brand and a loader', (tester, size, scale) async {
      final cubit = MockSessionCubit();
      whenListen(
        cubit,
        const Stream<SessionState>.empty(),
        initialState: const SessionUnknown(),
      );
      await pumpPage(
        tester,
        _with<SessionCubit>(cubit, const SplashPage()),
        size: size,
        textScale: scale,
      );
      expect(find.text('Dashuri'), findsOneWidget);
      expect(find.text('FOR ADULTS 18+ ONLY'), findsOneWidget);
    });

    testResponsive('account load failure offers retry and log out', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockSessionCubit();
      when(cubit.refreshAccount).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<SessionState>.empty(),
        initialState: SessionSignedIn(
          session: session,
          account: null,
          accountFailure: const NetworkFailure(),
        ),
      );
      var signedOut = false;
      await pumpPage(
        tester,
        _with<SessionCubit>(
          cubit,
          SplashPage(onSignOut: () => signedOut = true),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text("We couldn't load your account."), findsOneWidget);
      await tapVisible(tester, find.text('Try again'));
      verify(cubit.refreshAccount).called(1);
      await tapVisible(tester, find.text('Log out'));
      expect(signedOut, isTrue);
    });
  });

  group('WelcomePage (A02)', () {
    testResponsive('create account leads to phone entry in register mode', (
      tester,
      size,
      scale,
    ) async {
      await pumpPage(tester, const WelcomePage(), size: size, textScale: scale);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing); // D-02
      await tester.ensureVisible(find.text('Create account'));
      await tapVisible(tester, find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Navigated to /sign-in?mode=register'), findsOneWidget);
    });

    testWidgets('says when the backend is not configured', (tester) async {
      await pumpPage(tester, const WelcomePage(backendConfigured: false));
      expect(find.textContaining('Backend not configured'), findsOneWidget);
    });
  });

  group('PhonePage (A03/A04)', () {
    testResponsive('send is disabled until a valid number is entered', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockSignInCubit();
      when(() => cubit.sendCode(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<SignInState>.empty(),
        initialState: const SignInState(),
      );
      await pumpPage(
        tester,
        _with<SignInCubit>(cubit, const PhonePage(register: true)),
        size: size,
        textScale: scale,
      );
      expect(find.text("What's your number?"), findsOneWidget);
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '98765 43210');
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.tap(find.byType(FilledButton));
      verify(() => cubit.sendCode('98765 43210')).called(1);
    });

    testResponsive('shows a server failure inline', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockSignInCubit();
      whenListen(
        cubit,
        const Stream<SignInState>.empty(),
        initialState: const SignInState(failure: RateLimitedFailure()),
      );
      await pumpPage(
        tester,
        _with<SignInCubit>(cubit, const PhonePage()),
        size: size,
        textScale: scale,
      );
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.textContaining('Too many attempts'), findsOneWidget);
    });
  });

  group('OtpPage (A05/A06)', () {
    testResponsive('counts down before resend is offered', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockSignInCubit();
      whenListen(
        cubit,
        const Stream<SignInState>.empty(),
        initialState: const SignInState(
          step: SignInStep.awaitingCode,
          phone: '+919820417735',
          codesSent: 1,
        ),
      );
      await pumpPage(
        tester,
        _with<SignInCubit>(
          cubit,
          const OtpPage(resendAfter: Duration(seconds: 3)),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.textContaining('+91 98204 17735'), findsOneWidget);
      expect(find.text('Resend code in 0:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Resend code'), findsOneWidget);
    });

    testResponsive('error state explains the code did not match', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockSignInCubit();
      when(() => cubit.verifyCode(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<SignInState>.empty(),
        initialState: const SignInState(
          step: SignInStep.awaitingCode,
          phone: '+919820417735',
          codesSent: 1,
          failure: ValidationFailure(message: 'Token has expired'),
        ),
      );
      await pumpPage(
        tester,
        _with<SignInCubit>(cubit, const OtpPage()),
        size: size,
        textScale: scale,
      );
      expect(
        find.text("That code didn't match or has expired."),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      verify(() => cubit.verifyCode('123456')).called(1);
    });
  });

  group('CommunityRulesPage (A13)', () {
    testResponsive('lists the four rules and accepts', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockCommunityRulesCubit();
      when(cubit.accept).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<CommunityRulesState>.empty(),
        initialState: const CommunityRulesState(),
      );
      final session = MockSessionCubit();
      await pumpPage(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<CommunityRulesCubit>.value(value: cubit),
            BlocProvider<SessionCubit>.value(value: session),
          ],
          child: const CommunityRulesPage(),
        ),
        size: size,
        textScale: scale,
      );
      expect(find.text('Adults only, always'), findsOneWidget);
      await tapVisible(tester, find.text('I agree'));
      verify(cubit.accept).called(1);
    });

    testWidgets('applies the returned account to the session', (tester) async {
      final cubit = MockCommunityRulesCubit();
      whenListen(
        cubit,
        Stream.value(const CommunityRulesState(accepted: account)),
        initialState: const CommunityRulesState(submitting: true),
      );
      final session = MockSessionCubit();
      await pumpPage(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<CommunityRulesCubit>.value(value: cubit),
            BlocProvider<SessionCubit>.value(value: session),
          ],
          child: const CommunityRulesPage(),
        ),
      );
      await tester.pump();
      verify(() => session.applyAccount(account)).called(1);
    });

    testWidgets('shows an error with the failure', (tester) async {
      final cubit = MockCommunityRulesCubit();
      whenListen(
        cubit,
        const Stream<CommunityRulesState>.empty(),
        initialState: const CommunityRulesState(failure: NetworkFailure()),
      );
      await pumpPage(
        tester,
        _with<CommunityRulesCubit>(cubit, const CommunityRulesPage()),
      );
      expect(find.textContaining('offline'), findsOneWidget);
    });
  });

  group('PermissionsPage (A14/A15)', () {
    testResponsive('primer explains camera and microphone', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockPermissionsCubit();
      when(cubit.allow).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<PermissionsState>.empty(),
        initialState: const PermissionsState(),
      );
      await pumpPage(
        tester,
        _with<PermissionsCubit>(cubit, const PermissionsPage()),
        size: size,
        textScale: scale,
      );
      expect(find.text('Ready for your first call'), findsOneWidget);
      expect(find.text('So the person you call can see you'), findsOneWidget);
      await tapVisible(tester, find.text('Allow access'));
      verify(cubit.allow).called(1);
    });

    testResponsive('denied state offers Open settings', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockPermissionsCubit();
      when(cubit.openSettings).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<PermissionsState>.empty(),
        initialState: const PermissionsState(
          states: DevicePermissionStates({
            DevicePermission.camera: DevicePermissionState.permanentlyDenied,
            DevicePermission.microphone: DevicePermissionState.granted,
          }),
        ),
      );
      await pumpPage(
        tester,
        _with<PermissionsCubit>(cubit, const PermissionsPage()),
        size: size,
        textScale: scale,
      );
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Denied'), findsOneWidget);
      await tapVisible(tester, find.text('Open settings'));
      verify(cubit.openSettings).called(1);
    });
  });

  group('ChooseExperiencePage (A12)', () {
    testResponsive('offers customer and become a host', (
      tester,
      size,
      scale,
    ) async {
      final cubit = MockExperienceCubit();
      whenListen(
        cubit,
        const Stream<ExperienceState>.empty(),
        initialState: const ExperienceState(
          selected: ExperienceMode.customer,
          hostModeAvailable: false,
        ),
      );
      await pumpPage(
        tester,
        _with<ExperienceCubit>(cubit, const ChooseExperiencePage()),
        size: size,
        textScale: scale,
      );
      expect(find.text('Talk with hosts'), findsOneWidget);
      expect(find.text('Become a host'), findsOneWidget);
      await tapVisible(tester, find.text('Become a host'));
      verify(() => cubit.select(ExperienceMode.host)).called(1);
    });

    testWidgets('after saving host intent, goes to the host application', (
      tester,
    ) async {
      final cubit = MockExperienceCubit();
      whenListen(
        cubit,
        Stream.value(
          const ExperienceState(
            selected: ExperienceMode.host,
            hostModeAvailable: false,
            saved: true,
          ),
        ),
        initialState: const ExperienceState(
          selected: ExperienceMode.host,
          hostModeAvailable: false,
        ),
      );
      await pumpPage(
        tester,
        _with<ExperienceCubit>(cubit, const ChooseExperiencePage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Navigated to /host/apply'), findsOneWidget);
    });
  });
}
