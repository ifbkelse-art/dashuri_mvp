import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestOtp extends Mock implements RequestOtp {}

class MockVerifyOtp extends Mock implements VerifyOtp {}

class MockWatchSession extends Mock implements WatchSession {}

class MockGetAccountStatus extends Mock implements GetAccountStatus {}

class MockAcceptCommunityRules extends Mock implements AcceptCommunityRules {}

class MockGetDevicePermissions extends Mock implements GetDevicePermissions {}

class MockRequestDevicePermissions extends Mock
    implements RequestDevicePermissions {}

class MockOpenAppSettings extends Mock implements OpenAppSettings {}

class MockExperienceController extends Mock implements ExperienceController {}

class MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

class MockSignInCubit extends MockCubit<SignInState> implements SignInCubit {}

class MockCommunityRulesCubit extends MockCubit<CommunityRulesState>
    implements CommunityRulesCubit {}

class MockPermissionsCubit extends MockCubit<PermissionsState>
    implements PermissionsCubit {}

class MockExperienceCubit extends MockCubit<ExperienceState>
    implements ExperienceCubit {}

final session = AuthSession(userId: 'u1', expiresAt: DateTime.utc(2030));

const account = AccountStatus(
  userId: 'u1',
  ageEligible: true,
  isHost: false,
  restriction: null,
  profileComplete: true,
  rulesAccepted: true,
);
