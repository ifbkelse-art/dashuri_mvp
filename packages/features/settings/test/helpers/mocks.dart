import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:mocktail/mocktail.dart';

class MockGetMessagingPrivacy extends Mock implements GetMessagingPrivacy {}

class MockSetMessagingPrivacy extends Mock implements SetMessagingPrivacy {}

class MockRequestDataExport extends Mock implements RequestDataExport {}

class MockRequestAccountDeletion extends Mock
    implements RequestAccountDeletion {}

class MockSignOutUser extends Mock implements SignOutUser {}

class MockGetConsents extends Mock implements GetConsents {}

class MockUpdateConsents extends Mock implements UpdateConsents {}

class MockGetDiamondBalance extends Mock implements GetDiamondBalance {}

class MockSubmitGrievance extends Mock implements SubmitGrievance {}

class MockExperienceController extends Mock implements ExperienceController {}

class MockSessionGateway extends Mock implements SessionGateway {}

class MockSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class MockPrivacyCubit extends MockCubit<PrivacyState>
    implements PrivacyCubit {}

class MockConsentsCubit extends MockCubit<ConsentsState>
    implements ConsentsCubit {}

class MockGrievanceCubit extends MockCubit<GrievanceState>
    implements GrievanceCubit {}

class MockDeleteAccountCubit extends MockCubit<DeleteAccountState>
    implements DeleteAccountCubit {}

final consents = ConsentState(
  analytics: false,
  marketing: true,
  updatedAt: DateTime.utc(2026, 11, 1),
);
