import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const NoInput());
    registerFallbackValue(const ProfileUpdate());
    registerFallbackValue(ExperienceMode.customer);
    registerFallbackValue(IdempotencyKey.generate());
    registerFallbackValue((
      photo: const PickedPhoto(bytes: [], contentType: 'image/jpeg'),
      idempotencyKey: IdempotencyKey.generate(),
    ));
  });

  group('MyProfileCubit', () {
    late MockGetMyProfile getProfile;
    late MockGetMyLevel getLevel;
    late MockGetAvailableDiamonds getDiamonds;
    late MockExperienceController experience;

    setUp(() {
      getProfile = MockGetMyProfile();
      getLevel = MockGetMyLevel();
      getDiamonds = MockGetAvailableDiamonds();
      experience = MockExperienceController();
      when(() => experience.hostModeAvailable).thenReturn(true);
      when(() => experience.effectiveMode).thenReturn(ExperienceMode.customer);
      when(() => experience.setMode(any())).thenAnswer((_) async {});
      when(() => getLevel(any())).thenAnswer((_) async => const Success(level));
      when(
        () => getDiamonds(any()),
      ).thenAnswer((_) async => const Success(500));
    });

    MyProfileCubit build() =>
        MyProfileCubit(getProfile, getLevel, getDiamonds, experience);

    blocTest<MyProfileCubit, MyProfileState>(
      'loads profile, level and diamonds together',
      setUp: () => when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(profile)),
      build: build,
      act: (c) => c.load(),
      expect: () => const [
        MyProfileStateLoading(),
        MyProfileStateLoaded(
          profile,
          level: level,
          availableDiamonds: 500,
          hostModeAvailable: true,
        ),
      ],
    );

    blocTest<MyProfileCubit, MyProfileState>(
      'level and wallet failures are not fatal',
      setUp: () {
        when(
          () => getProfile(any()),
        ).thenAnswer((_) async => const Success(profile));
        when(
          () => getLevel(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        when(
          () => getDiamonds(any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: build,
      act: (c) => c.load(),
      expect: () => const [
        MyProfileStateLoading(),
        MyProfileStateLoaded(profile, hostModeAvailable: true),
      ],
    );

    blocTest<MyProfileCubit, MyProfileState>(
      'profile failure fails the page',
      setUp: () => when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (c) => c.load(),
      expect: () => const [
        MyProfileStateLoading(),
        MyProfileStateFailed(NetworkFailure()),
      ],
    );

    blocTest<MyProfileCubit, MyProfileState>(
      'setMode stores the experience',
      build: build,
      seed: () => const MyProfileStateLoaded(profile, hostModeAvailable: true),
      act: (c) => c.setMode(ExperienceMode.host),
      expect: () => const [
        MyProfileStateLoaded(
          profile,
          hostModeAvailable: true,
          mode: ExperienceMode.host,
        ),
      ],
      verify: (_) => verify(() => experience.setMode(ExperienceMode.host)),
    );
  });

  group('CreateProfileCubit', () {
    late MockUpdateMyProfile update;
    late MockRefresher refresher;
    setUp(() {
      update = MockUpdateMyProfile();
      refresher = MockRefresher();
      when(refresher.refreshAccountStatus).thenAnswer((_) async {});
    });

    test('needs a 2–20 character name and a gender', () {
      expect(
        const CreateProfileState(name: 'A', gender: Gender.man).canSubmit,
        isFalse,
      );
      expect(const CreateProfileState(name: 'Arjun').canSubmit, isFalse);
      expect(
        const CreateProfileState(name: 'Arjun', gender: Gender.man).canSubmit,
        isTrue,
      );
    });

    blocTest<CreateProfileCubit, CreateProfileState>(
      'submit saves name + gender and refreshes the account',
      setUp: () => when(
        () => update(any()),
      ).thenAnswer((_) async => const Success(profile)),
      build: () => CreateProfileCubit(update, refresher),
      seed: () => const CreateProfileState(name: ' Arjun ', gender: Gender.man),
      act: (c) => c.submit(),
      expect: () => const [
        CreateProfileState(
          name: ' Arjun ',
          gender: Gender.man,
          submitting: true,
        ),
        CreateProfileState(name: ' Arjun ', gender: Gender.man, done: true),
      ],
      verify: (_) {
        verify(
          () => update(
            const ProfileUpdate(displayName: 'Arjun', gender: Gender.man),
          ),
        ).called(1);
        verify(refresher.refreshAccountStatus).called(1);
      },
    );

    blocTest<CreateProfileCubit, CreateProfileState>(
      'contact details in the name are flagged inline',
      setUp: () => when(() => update(any())).thenAnswer(
        (_) async =>
            const Err(BusinessRuleFailure(code: 'profile_text_rejected')),
      ),
      build: () => CreateProfileCubit(update, refresher),
      seed: () =>
          const CreateProfileState(name: 'insta me', gender: Gender.man),
      act: (c) => c.submit(),
      skip: 1,
      expect: () => const [
        CreateProfileState(
          name: 'insta me',
          gender: Gender.man,
          failure: BusinessRuleFailure(code: 'profile_text_rejected'),
          nameRejected: true,
        ),
      ],
      verify: (_) => verifyNever(refresher.refreshAccountStatus),
    );
  });

  group('EditProfileCubit', () {
    late MockGetMyProfile getProfile;
    late MockUpdateMyProfile update;
    late MockUploadProfilePhoto upload;
    late MockPhotoPicker picker;

    setUp(() {
      getProfile = MockGetMyProfile();
      update = MockUpdateMyProfile();
      upload = MockUploadProfilePhoto();
      picker = MockPhotoPicker();
      when(
        () => getProfile(any()),
      ).thenAnswer((_) async => const Success(profile));
    });

    test('load fills the form; save is enabled only after a change', () async {
      final c = EditProfileCubit(getProfile, update, upload);
      await c.load();
      expect(c.state.name, 'Arjun');
      expect(c.state.canSave, isFalse);
      expect(c.state.photoUploadAvailable, isFalse);
      c.nameChanged('Arjun K');
      expect(c.state.canSave, isTrue);
      c.nameChanged('Arjun');
      expect(c.state.canSave, isFalse);
      c.toggleLanguage('ta');
      expect(c.state.languages, ['hi', 'en', 'ta']);
      expect(c.state.canSave, isTrue);
      await c.close();
    });

    test('save sends only changed fields', () async {
      when(() => update(any())).thenAnswer((_) async => const Success(profile));
      final c = EditProfileCubit(getProfile, update, upload);
      await c.load();
      c
        ..bioChanged('New bio')
        ..genderChanged(Gender.preferNotToSay);
      await c.save();
      verify(
        () => update(
          const ProfileUpdate(bio: 'New bio', gender: Gender.preferNotToSay),
        ),
      ).called(1);
      expect(c.state.saved, isTrue);
      await c.close();
    });

    test('a rejected bio is attributed to the bio field', () async {
      when(() => update(any())).thenAnswer(
        (_) async => const Err(
          ValidationFailure(fieldErrors: {'bio': 'profile_text_rejected'}),
        ),
      );
      final c = EditProfileCubit(getProfile, update, upload);
      await c.load();
      c.bioChanged('mail me at a@b.c');
      await c.save();
      expect(c.state.rejectedField, 'bio');
      c.bioChanged('fine');
      expect(c.state.rejectedField, isNull);
      await c.close();
    });

    test('clearCity sends city_id null', () async {
      when(() => update(any())).thenAnswer((_) async => const Success(profile));
      final c = EditProfileCubit(getProfile, update, upload);
      await c.load();
      await c.clearCity();
      verify(() => update(const ProfileUpdate(clearCity: true))).called(1);
      await c.close();
    });

    test('photo upload reuses the key for a retry of the same photo', () async {
      const photo = PickedPhoto(bytes: [1, 2], contentType: 'image/jpeg');
      when(picker.pick).thenAnswer((_) async => photo);
      final keys = <String>[];
      var call = 0;
      when(() => upload(any())).thenAnswer((inv) async {
        final input =
            inv.positionalArguments.first
                as ({PickedPhoto photo, IdempotencyKey idempotencyKey});
        keys.add(input.idempotencyKey.value);
        return call++ == 0 ? const Err(NetworkFailure()) : const Success('p1');
      });
      final c = EditProfileCubit(
        getProfile,
        update,
        upload,
        photoPicker: picker,
      );
      await c.load();
      expect(c.state.photoUploadAvailable, isTrue);
      await c.pickAndUploadPhoto();
      expect(c.state.photoFailure, const NetworkFailure());
      await c.pickAndUploadPhoto();
      expect(c.state.photoSubmitted, isTrue);
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(1));
      verify(picker.pick).called(1);
      await c.close();
    });
  });

  group('UploadProfilePhoto', () {
    test('requests a ticket then uploads the bytes', () async {
      final repo = MockProfileRepository();
      final ticket = PhotoUploadTicket(
        photoId: 'p1',
        uploadUrl: 'https://signed',
        expiresAt: DateTime.utc(2030),
      );
      registerFallbackValue(ticket);
      when(
        () => repo.requestPhotoUpload(
          contentType: any(named: 'contentType'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async => Success(ticket));
      when(
        () => repo.uploadPhotoBytes(
          ticket: any(named: 'ticket'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
        ),
      ).thenAnswer((_) async => const Success(null));
      final result = await UploadProfilePhoto(repo)((
        photo: const PickedPhoto(bytes: [9], contentType: 'image/png'),
        idempotencyKey: IdempotencyKey.generate(),
      ));
      expect((result as Success<String>).value, 'p1');
      verify(
        () => repo.uploadPhotoBytes(
          ticket: ticket,
          bytes: [9],
          contentType: 'image/png',
        ),
      ).called(1);
    });
  });
}
