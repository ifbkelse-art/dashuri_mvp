import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:mocktail/mocktail.dart';

class MockGetMyProfile extends Mock implements GetMyProfile {}

class MockGetMyLevel extends Mock implements GetMyLevel {}

class MockGetAvailableDiamonds extends Mock implements GetAvailableDiamonds {}

class MockUpdateMyProfile extends Mock implements UpdateMyProfile {}

class MockUploadProfilePhoto extends Mock implements UploadProfilePhoto {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

class MockExperienceController extends Mock implements ExperienceController {}

class MockRefresher extends Mock implements AccountStatusRefresher {}

class MockMyProfileCubit extends MockCubit<MyProfileState>
    implements MyProfileCubit {}

class MockEditProfileCubit extends MockCubit<EditProfileState>
    implements EditProfileCubit {}

class MockCreateProfileCubit extends MockCubit<CreateProfileState>
    implements CreateProfileCubit {}

const profile = Profile(
  userId: 'u1',
  displayName: 'Arjun',
  bio: 'Hello',
  languages: ['hi', 'en'],
  photoUrls: [],
  isHost: false,
  level: 2,
  gender: Gender.man,
  city: ProfileCity(id: 'pune', name: 'Pune', state: 'Maharashtra'),
);

const level = LevelProgress(
  level: 2,
  lifetimeXp: 168,
  currentLevelXp: 100,
  nextLevelXp: 200,
);
