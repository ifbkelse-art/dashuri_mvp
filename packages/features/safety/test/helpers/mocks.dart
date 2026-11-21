import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:mocktail/mocktail.dart';

class MockSubmitAgeDeclaration extends Mock implements SubmitAgeDeclaration {}

class MockReportUser extends Mock implements ReportUser {}

class MockBlockUser extends Mock implements BlockUser {}

class MockUnblockUser extends Mock implements UnblockUser {}

class MockListBlockedUsers extends Mock implements ListBlockedUsers {}

class MockListEnforcementNotices extends Mock
    implements ListEnforcementNotices {}

class MockSubmitAppeal extends Mock implements SubmitAppeal {}

class MockRefresher extends Mock implements AccountStatusRefresher {}

class FixedClock implements Clock {
  FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

class MockAgeGateCubit extends MockCubit<AgeGateState>
    implements AgeGateCubit {}

class MockReportCubit extends MockCubit<ReportState> implements ReportCubit {}

class MockBlockCubit extends MockCubit<BlockState> implements BlockCubit {}

class MockBlockedUsersCubit extends MockCubit<BlockedUsersState>
    implements BlockedUsersCubit {}

class MockEnforcementCubit extends MockCubit<EnforcementState>
    implements EnforcementCubit {}

final blocked = BlockedUser(
  userId: 'b1',
  displayName: 'Tara',
  blockedAt: DateTime.utc(2026, 11, 12),
);

final notice = EnforcementNotice(
  id: 'e1',
  action: 'warning',
  reason: 'Sharing contact details in chat.',
  createdAt: DateTime.utc(2026, 11, 10),
  appealable: true,
);
