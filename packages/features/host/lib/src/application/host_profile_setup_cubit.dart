import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_photo.dart';
import '../domain/entities/host_profile.dart';
import '../domain/usecases/get_my_host_profile.dart';
import '../domain/usecases/update_host_profile.dart';
import '../domain/usecases/upload_host_photo.dart';

enum HostProfileSetupStatus { loading, loadFailed, ready, saving, saved }

/// Client-side limits for H09 (the API allows a 300-character bio; the
/// design caps it at 150).
abstract final class HostProfileLimits {
  static const displayNameMax = 40;
  static const bioMax = 150;
  static const maxPhotos = 6;
}

final class HostProfileSetupState extends Equatable {
  const HostProfileSetupState({
    this.status = HostProfileSetupStatus.loading,
    this.profile,
    this.failure,
    this.fieldErrors = const {},
    this.uploadingPhoto = false,
    this.photoFailure,
    this.photosSubmitted = 0,
  });

  final HostProfileSetupStatus status;
  final HostProfile? profile;

  /// Load failure (loadFailed) or the last save failure (ready).
  final Failure? failure;

  /// Local validation: field → reason (`required`, `too_long`).
  final Map<String, String> fieldErrors;
  final bool uploadingPhoto;
  final Failure? photoFailure;

  /// Photos uploaded in this session; they stay private until moderated and
  /// are not in `photo_urls` until approved.
  final int photosSubmitted;

  int get photoCount => (profile?.photoUrls.length ?? 0) + photosSubmitted;

  HostProfileSetupState copyWith({
    HostProfileSetupStatus? status,
    HostProfile? profile,
    Failure? failure,
    Map<String, String>? fieldErrors,
    bool? uploadingPhoto,
    Failure? photoFailure,
    int? photosSubmitted,
  }) => HostProfileSetupState(
    status: status ?? this.status,
    profile: profile ?? this.profile,
    failure: failure,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
    photoFailure: photoFailure,
    photosSubmitted: photosSubmitted ?? this.photosSubmitted,
  );

  @override
  List<Object?> get props => [
    status,
    profile,
    failure,
    fieldErrors,
    uploadingPhoto,
    photoFailure,
    photosSubmitted,
  ];
}

/// H09: display name, bio and languages (PATCH /v1/me/profile) and photos
/// (upload ticket + signed upload).
final class HostProfileSetupCubit extends Cubit<HostProfileSetupState> {
  HostProfileSetupCubit(this._getProfile, this._updateProfile, this._upload)
    : super(const HostProfileSetupState());

  final GetMyHostProfile _getProfile;
  final UpdateHostProfile _updateProfile;
  final UploadHostPhoto _upload;

  Future<void> load() async {
    emit(const HostProfileSetupState());
    final result = await _getProfile(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => HostProfileSetupState(
        status: HostProfileSetupStatus.ready,
        profile: value,
      ),
      Err(:final failure) => HostProfileSetupState(
        status: HostProfileSetupStatus.loadFailed,
        failure: failure,
      ),
    });
  }

  static Map<String, String> validate({
    required String displayName,
    required String bio,
    required List<String> languages,
  }) {
    final name = displayName.trim();
    return {
      if (name.isEmpty) 'display_name': 'required',
      if (name.length > HostProfileLimits.displayNameMax)
        'display_name': 'too_long',
      if (bio.trim().length > HostProfileLimits.bioMax) 'bio': 'too_long',
      if (languages.isEmpty) 'languages': 'required',
    };
  }

  Future<void> save({
    required String displayName,
    required String bio,
    required List<String> languages,
  }) async {
    if (state.status == HostProfileSetupStatus.saving) return;
    final errors = validate(
      displayName: displayName,
      bio: bio,
      languages: languages,
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(fieldErrors: errors));
      return;
    }
    emit(
      state.copyWith(status: HostProfileSetupStatus.saving, fieldErrors: {}),
    );
    final result = await _updateProfile((
      displayName: displayName.trim(),
      bio: bio.trim().isEmpty ? null : bio.trim(),
      languages: languages,
    ));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => state.copyWith(
        status: HostProfileSetupStatus.saved,
        profile: value,
      ),
      Err(failure: ValidationFailure(:final fieldErrors)) when fieldErrors
          .isNotEmpty =>
        state.copyWith(
          status: HostProfileSetupStatus.ready,
          fieldErrors: fieldErrors,
        ),
      Err(:final failure) => state.copyWith(
        status: HostProfileSetupStatus.ready,
        failure: failure,
      ),
    });
  }

  /// Uploads one photo. A fresh idempotency key per chosen photo.
  Future<void> addPhoto(PickedPhoto photo) async {
    if (state.uploadingPhoto) return;
    if (state.photoCount >= HostProfileLimits.maxPhotos) {
      emit(
        state.copyWith(
          photoFailure: const BusinessRuleFailure(code: 'photo_limit_reached'),
        ),
      );
      return;
    }
    emit(state.copyWith(uploadingPhoto: true));
    final result = await _upload((
      photo: photo,
      idempotencyKey: IdempotencyKey.generate(),
    ));
    if (isClosed) return;
    emit(switch (result) {
      Success() => state.copyWith(
        uploadingPhoto: false,
        photosSubmitted: state.photosSubmitted + 1,
      ),
      Err(:final failure) => state.copyWith(
        uploadingPhoto: false,
        photoFailure: failure,
      ),
    });
  }
}
