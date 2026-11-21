import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/profile.dart';
import '../domain/ports/photo_picker.dart';
import '../domain/usecases/get_my_profile.dart';
import '../domain/usecases/update_my_profile.dart';
import '../domain/usecases/upload_profile_photo.dart';
import 'profile_failure.dart';

/// S02 edit profile. Save is enabled only when something changed.
class EditProfileCubit extends Cubit<EditProfileState> {
  EditProfileCubit(
    this._getMyProfile,
    this._update,
    this._uploadPhoto, {
    PhotoPicker? photoPicker,
  }) : _picker = photoPicker,
       super(EditProfileState(photoUploadAvailable: photoPicker != null));

  final GetMyProfile _getMyProfile;
  final UpdateMyProfile _update;
  final UploadProfilePhoto _uploadPhoto;
  final PhotoPicker? _picker;
  IdempotencyKey? _photoKey;
  PickedPhoto? _pendingPhoto;

  Future<void> load() async {
    emit(state.copyWith(status: EditProfileStatus.loading));
    final result = await _getMyProfile(const NoInput());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => state.loaded(value),
      Err(:final failure) => state.copyWith(
        status: EditProfileStatus.failed,
        loadFailure: failure,
      ),
    });
  }

  void nameChanged(String v) => emit(state.copyWith(name: v, clearSave: true));

  void bioChanged(String v) => emit(state.copyWith(bio: v, clearSave: true));

  void genderChanged(Gender g) =>
      emit(state.copyWith(gender: g, clearSave: true));

  void toggleLanguage(String code) {
    final next = [...state.languages];
    next.contains(code) ? next.remove(code) : next.add(code);
    emit(state.copyWith(languages: next, clearSave: true));
  }

  Future<void> save() async {
    final original = state.original;
    if (original == null || !state.canSave) return;
    emit(state.copyWith(saving: true, clearSave: true));
    final name = state.name.trim();
    final bio = state.bio.trim();
    final result = await _update(
      ProfileUpdate(
        displayName: name == original.displayName ? null : name,
        bio: bio == (original.bio ?? '') ? null : bio,
        languages: _sameLanguages(state.languages, original.languages)
            ? null
            : state.languages,
        gender: state.gender == original.gender ? null : state.gender,
      ),
    );
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => state.loaded(value).copyWith(saved: true),
      Err(:final failure) => state.copyWith(
        saving: false,
        saveFailure: failure,
        rejectedField: rejectedProfileField(failure),
      ),
    });
  }

  /// Removes the city (`city_id: null`).
  Future<void> clearCity() async {
    emit(state.copyWith(saving: true, clearSave: true));
    final result = await _update(const ProfileUpdate(clearCity: true));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => state.copyWith(
        saving: false,
        original: value,
        clearCity: true,
      ),
      Err(:final failure) => state.copyWith(
        saving: false,
        saveFailure: failure,
      ),
    });
  }

  /// After the city picker saved a city, re-read it from the server.
  Future<void> reloadCity() async {
    final result = await _getMyProfile(const NoInput());
    if (result case Success(:final value) when !isClosed) {
      emit(state.copyWith(original: value, city: value.city, clearCity: true));
    }
  }

  Future<void> pickAndUploadPhoto() async {
    final picker = _picker;
    if (picker == null || state.uploadingPhoto) return;
    final photo = _pendingPhoto ?? await picker.pick();
    if (photo == null || isClosed) return;
    if (_pendingPhoto != photo) {
      _pendingPhoto = photo;
      _photoKey = IdempotencyKey.generate();
    }
    emit(state.copyWith(uploadingPhoto: true, clearPhoto: true));
    final result = await _uploadPhoto((
      photo: photo,
      idempotencyKey: _photoKey!,
    ));
    if (isClosed) return;
    switch (result) {
      case Success():
        _pendingPhoto = null;
        emit(state.copyWith(uploadingPhoto: false, photoSubmitted: true));
      case Err(:final failure):
        emit(state.copyWith(uploadingPhoto: false, photoFailure: failure));
    }
  }

  /// Forgets a photo whose upload failed, so the next tap picks a new one.
  void discardPendingPhoto() => _pendingPhoto = null;

  static bool _sameLanguages(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}

enum EditProfileStatus { loading, ready, failed }

final class EditProfileState extends Equatable {
  const EditProfileState({
    this.status = EditProfileStatus.loading,
    this.original,
    this.loadFailure,
    this.name = '',
    this.bio = '',
    this.languages = const [],
    this.gender,
    this.city,
    this.saving = false,
    this.saved = false,
    this.saveFailure,
    this.rejectedField,
    this.photoUploadAvailable = false,
    this.uploadingPhoto = false,
    this.photoSubmitted = false,
    this.photoFailure,
  });

  final EditProfileStatus status;
  final Profile? original;
  final Failure? loadFailure;
  final String name;
  final String bio;
  final List<String> languages;
  final Gender? gender;
  final ProfileCity? city;
  final bool saving;
  final bool saved;
  final Failure? saveFailure;

  /// `display_name`, `bio` or `any` when contact details were rejected.
  final String? rejectedField;
  final bool photoUploadAvailable;
  final bool uploadingPhoto;

  /// A new photo was uploaded and awaits moderation.
  final bool photoSubmitted;
  final Failure? photoFailure;

  bool get nameValid {
    final n = name.trim().length;
    return n >= displayNameMinLength && n <= displayNameMaxLength;
  }

  bool get dirty {
    final o = original;
    if (o == null) return false;
    return name.trim() != o.displayName ||
        bio.trim() != (o.bio ?? '') ||
        gender != o.gender ||
        !EditProfileCubit._sameLanguages(languages, o.languages);
  }

  bool get canSave =>
      dirty && nameValid && bio.length <= bioMaxLength && !saving;

  EditProfileState loaded(Profile p) => EditProfileState(
    status: EditProfileStatus.ready,
    original: p,
    name: p.displayName,
    bio: p.bio ?? '',
    languages: [...p.languages],
    gender: p.gender,
    city: p.city,
    photoUploadAvailable: photoUploadAvailable,
    photoSubmitted: photoSubmitted,
  );

  EditProfileState copyWith({
    EditProfileStatus? status,
    Profile? original,
    Failure? loadFailure,
    String? name,
    String? bio,
    List<String>? languages,
    Gender? gender,
    ProfileCity? city,
    bool? saving,
    bool? saved,
    Failure? saveFailure,
    String? rejectedField,
    bool? uploadingPhoto,
    bool? photoSubmitted,
    Failure? photoFailure,
    bool clearSave = false,
    bool clearCity = false,
    bool clearPhoto = false,
  }) => EditProfileState(
    status: status ?? this.status,
    original: original ?? this.original,
    loadFailure: loadFailure ?? this.loadFailure,
    name: name ?? this.name,
    bio: bio ?? this.bio,
    languages: languages ?? this.languages,
    gender: gender ?? this.gender,
    city: city ?? (clearCity ? null : this.city),
    saving: saving ?? this.saving,
    saved: saved ?? (clearSave ? false : this.saved),
    saveFailure: clearSave ? null : (saveFailure ?? this.saveFailure),
    rejectedField: clearSave ? null : (rejectedField ?? this.rejectedField),
    photoUploadAvailable: photoUploadAvailable,
    uploadingPhoto: uploadingPhoto ?? this.uploadingPhoto,
    photoSubmitted:
        photoSubmitted ?? (clearPhoto ? false : this.photoSubmitted),
    photoFailure: clearPhoto ? null : (photoFailure ?? this.photoFailure),
  );

  @override
  List<Object?> get props => [
    status,
    original,
    loadFailure,
    name,
    bio,
    languages,
    gender,
    city,
    saving,
    saved,
    saveFailure,
    rejectedField,
    photoUploadAvailable,
    uploadingPhoto,
    photoSubmitted,
    photoFailure,
  ];
}
