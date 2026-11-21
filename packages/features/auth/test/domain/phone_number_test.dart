import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndianPhoneNumber', () {
    test('accepts 10 digits starting 6–9 in common formats', () {
      for (final input in [
        '9820417735',
        '98204 17735',
        '+91 98204 17735',
        '919820417735',
        '09820417735',
        '6000000000',
      ]) {
        expect(
          IndianPhoneNumber.toE164(input),
          startsWith('+91'),
          reason: input,
        );
      }
      expect(IndianPhoneNumber.toE164('98204 17735'), '+919820417735');
    });

    test('rejects short, long, landline-like or foreign numbers', () {
      for (final input in [
        '',
        '98204',
        '5820417735',
        '98204177351',
        '+1 2025550123',
        'abcdefghij',
      ]) {
        expect(IndianPhoneNumber.toE164(input), isNull, reason: input);
      }
    });

    test('formats for display', () {
      expect(IndianPhoneNumber.format('+919820417735'), '+91 98204 17735');
    });
  });

  test('AccountStatus.isApprovedHost needs is_host and approved state', () {
    const base = AccountStatus(
      userId: 'u',
      ageEligible: true,
      isHost: true,
      restriction: null,
      hostState: 'kyc_pending',
    );
    expect(base.isApprovedHost, isFalse);
    expect(
      const AccountStatus(
        userId: 'u',
        ageEligible: true,
        isHost: true,
        restriction: null,
        hostState: 'approved',
      ).isApprovedHost,
      isTrue,
    );
  });

  test('DevicePermissionStates.callReady needs camera and microphone', () {
    const states = DevicePermissionStates({
      DevicePermission.camera: DevicePermissionState.granted,
      DevicePermission.microphone: DevicePermissionState.permanentlyDenied,
    });
    expect(states.callReady, isFalse);
    expect(states.anyRequiredPermanentlyDenied, isTrue);
    expect(
      states.of(DevicePermission.notifications),
      DevicePermissionState.denied,
    );
  });
}
