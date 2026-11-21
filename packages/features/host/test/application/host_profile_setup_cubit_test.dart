import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockGetMyHostProfile getProfile;
  late MockUpdateHostProfile update;
  late MockUploadHostPhoto upload;
  final ticket = PhotoUploadTicket(
    photoId: 'p1',
    uploadUrl: Uri.parse('https://storage.example/upload'),
    expiresAt: DateTime.utc(2026, 11, 21),
  );
  const ready = HostProfileSetupState(
    status: HostProfileSetupStatus.ready,
    profile: sampleProfile,
  );

  HostProfileSetupCubit build() =>
      HostProfileSetupCubit(getProfile, update, upload);

  setUpAll(registerHostFallbacks);
  setUp(() {
    getProfile = MockGetMyHostProfile();
    update = MockUpdateHostProfile();
    upload = MockUploadHostPhoto();
  });

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'loads the profile',
    setUp: () => when(
      () => getProfile(any()),
    ).thenAnswer((_) async => const Success(sampleProfile)),
    build: build,
    act: (c) => c.load(),
    expect: () => const [HostProfileSetupState(), ready],
  );

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'local validation blocks an empty name, long bio and no languages',
    build: build,
    seed: () => ready,
    act: (c) => c.save(displayName: '  ', bio: 'x' * 151, languages: []),
    expect: () => [
      const HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        fieldErrors: {
          'display_name': 'required',
          'bio': 'too_long',
          'languages': 'required',
        },
      ),
    ],
    verify: (_) => verifyNever(() => update(any())),
  );

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'save trims values and emits saved',
    setUp: () => when(
      () => update(any()),
    ).thenAnswer((_) async => const Success(sampleProfile)),
    build: build,
    seed: () => ready,
    act: (c) => c.save(displayName: ' Ananya ', bio: '  ', languages: ['hi']),
    expect: () => const [
      HostProfileSetupState(
        status: HostProfileSetupStatus.saving,
        profile: sampleProfile,
      ),
      HostProfileSetupState(
        status: HostProfileSetupStatus.saved,
        profile: sampleProfile,
      ),
    ],
    verify: (_) {
      final input =
          verify(() => update(captureAny())).captured.single
              as UpdateHostProfileInput;
      expect(input.displayName, 'Ananya');
      expect(input.bio, isNull);
      expect(input.languages, ['hi']);
    },
  );

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'profile_text_rejected is reported',
    setUp: () => when(() => update(any())).thenAnswer(
      (_) async =>
          const Err(BusinessRuleFailure(code: 'profile_text_rejected')),
    ),
    build: build,
    seed: () => ready,
    act: (c) => c.save(displayName: 'A', bio: 'call 98', languages: ['hi']),
    skip: 1,
    expect: () => const [
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        failure: BusinessRuleFailure(code: 'profile_text_rejected'),
      ),
    ],
  );

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'photo upload success and failure',
    setUp: () {
      var n = 0;
      when(() => upload(any())).thenAnswer(
        (_) async => n++ == 0
            ? Success(ticket)
            : const Err(ServerFailure(code: 'photo_upload_failed')),
      );
    },
    build: build,
    seed: () => ready,
    act: (c) async {
      await c.addPhoto(samplePhoto);
      await c.addPhoto(samplePhoto);
    },
    expect: () => const [
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        uploadingPhoto: true,
      ),
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        photosSubmitted: 1,
      ),
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        uploadingPhoto: true,
        photosSubmitted: 1,
      ),
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        photosSubmitted: 1,
        photoFailure: ServerFailure(code: 'photo_upload_failed'),
      ),
    ],
  );

  blocTest<HostProfileSetupCubit, HostProfileSetupState>(
    'refuses a seventh photo locally',
    build: build,
    seed: () => const HostProfileSetupState(
      status: HostProfileSetupStatus.ready,
      profile: sampleProfile,
      photosSubmitted: 6,
    ),
    act: (c) => c.addPhoto(samplePhoto),
    expect: () => const [
      HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: sampleProfile,
        photosSubmitted: 6,
        photoFailure: BusinessRuleFailure(code: 'photo_limit_reached'),
      ),
    ],
  );
}
