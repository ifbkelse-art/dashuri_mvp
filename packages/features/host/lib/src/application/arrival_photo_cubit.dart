import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/arrival_photo.dart';
import '../domain/entities/host_photo.dart';
import '../domain/ports/arrival_camera.dart';
import '../domain/usecases/session_usecases.dart';

sealed class ArrivalState extends Equatable {
  const ArrivalState();

  @override
  List<Object?> get props => [];
}

/// Not loaded yet.
final class ArrivalIdle extends ArrivalState {
  const ArrivalIdle();
}

/// The current session's photo (null: none).
final class ArrivalLoaded extends ArrivalState {
  const ArrivalLoaded(this.current);

  final ArrivalPhoto? current;

  @override
  List<Object?> get props => [current];
}

/// "Would you like to capture an arrival photo?" (Capture / Skip).
final class ArrivalPrompt extends ArrivalState {
  const ArrivalPrompt();
}

/// The in-app camera is open.
final class ArrivalCapturing extends ArrivalState {
  const ArrivalCapturing();
}

/// Preview: Retake or Use photo.
final class ArrivalPreview extends ArrivalState {
  const ArrivalPreview(this.photo);

  final PickedPhoto photo;

  @override
  List<Object?> get props => [photo.bytes.length, photo.contentType];
}

/// The host chose the photo; it is uploaded once the session exists.
final class ArrivalConfirmed extends ArrivalState {
  const ArrivalConfirmed(this.photo);

  final PickedPhoto photo;

  @override
  List<Object?> get props => [photo.bytes.length];
}

final class ArrivalUploading extends ArrivalState {
  const ArrivalUploading(this.photo);

  final PickedPhoto photo;

  @override
  List<Object?> get props => [photo.bytes.length];
}

/// Upload failed; [retryable] keeps the same photo for "Try again".
final class ArrivalFailed extends ArrivalState {
  const ArrivalFailed(this.failure, {this.photo});

  final Failure failure;
  final PickedPhoto? photo;

  bool get retryable =>
      photo != null && (failure is NetworkFailure || failure is ServerFailure);

  @override
  List<Object?> get props => [failure, photo?.bytes.length];
}

/// The host skipped the photo for this session.
final class ArrivalSkipped extends ArrivalState {
  const ArrivalSkipped();
}

/// The optional arrival photo flow. Camera only (the [ArrivalCamera] port
/// never offers the gallery); a new capture for every session; skipping is
/// always possible and never affects going online.
final class ArrivalPhotoCubit extends Cubit<ArrivalState> {
  ArrivalPhotoCubit({
    required ArrivalCamera camera,
    required SubmitArrivalPhoto submit,
    required GetArrivalPhoto current,
    required RemoveArrivalPhoto remove,
  }) : _camera = camera,
       _submit = submit,
       _current = current,
       _remove = remove,
       super(const ArrivalIdle());

  final ArrivalCamera _camera;
  final SubmitArrivalPhoto _submit;
  final GetArrivalPhoto _current;
  final RemoveArrivalPhoto _remove;

  Future<void> load() async {
    final r = await _current(const NoInput());
    if (isClosed) return;
    if (r case Success(:final value)) emit(ArrivalLoaded(value));
  }

  void prompt() => emit(const ArrivalPrompt());

  void skip() => emit(const ArrivalSkipped());

  Future<void> capture() async {
    if (state is ArrivalCapturing || state is ArrivalUploading) return;
    emit(const ArrivalCapturing());
    final photo = await _camera.capture();
    if (isClosed) return;
    emit(photo == null ? const ArrivalPrompt() : ArrivalPreview(photo));
  }

  /// Retake discards the previewed photo and opens the camera again.
  Future<void> retake() => capture();

  /// "Use photo" before the session exists: kept for [upload].
  void confirm() {
    if (state case ArrivalPreview(:final photo)) emit(ArrivalConfirmed(photo));
  }

  /// Uploads the confirmed (or failed, for a retry) photo to the CURRENT
  /// online session. Each attempt uses a fresh ticket.
  Future<void> upload() async {
    final photo = switch (state) {
      ArrivalConfirmed(:final photo) || ArrivalPreview(:final photo) => photo,
      final ArrivalFailed f when f.photo != null => f.photo,
      _ => null,
    };
    if (photo == null) return;
    emit(ArrivalUploading(photo));
    final r = await _submit(photo);
    if (isClosed) return;
    switch (r) {
      case Success(:final value):
        emit(ArrivalLoaded(value));
      case Err(:final failure):
        emit(ArrivalFailed(failure, photo: photo));
    }
  }

  Future<void> removeCurrent() async {
    final r = await _remove(const NoInput());
    if (isClosed) return;
    if (r is Success) emit(const ArrivalLoaded(null));
  }
}
