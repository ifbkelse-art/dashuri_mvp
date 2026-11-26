import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_photo.dart';
import '../domain/entities/host_verification.dart';
import '../domain/repositories/host_verification_repository.dart';

enum VerifiedHostStatus { loading, loadFailed, ready, uploading, submitting }

final class VerifiedHostState extends Equatable {
  const VerifiedHostState({
    this.status = VerifiedHostStatus.loading,
    this.verification,
    this.uploadingKind,
    this.failure,
    this.submitted = false,
  });

  final VerifiedHostStatus status;
  final HostVerification? verification;
  final EvidenceKind? uploadingKind;
  final Failure? failure;

  /// True right after a successful submission (for a confirmation).
  final bool submitted;

  @override
  List<Object?> get props => [
    status,
    verification,
    uploadingKind,
    failure,
    submitted,
  ];
}

/// Verified Host application: upload private evidence, submit, follow the
/// review. The server decides everything; the app only shows its answer.
final class VerifiedHostCubit extends Cubit<VerifiedHostState> {
  VerifiedHostCubit(this._repo) : super(const VerifiedHostState());

  final HostVerificationRepository _repo;
  IdempotencyKey? _submitKey;

  Future<void> load() async {
    emit(const VerifiedHostState());
    final r = await _repo.getVerification();
    if (isClosed) return;
    emit(switch (r) {
      Success(:final value) => VerifiedHostState(
        status: VerifiedHostStatus.ready,
        verification: value,
      ),
      Err(:final failure) => VerifiedHostState(
        status: VerifiedHostStatus.loadFailed,
        failure: failure,
      ),
    });
  }

  Future<void> upload(EvidenceKind kind, PickedPhoto? media) async {
    final v = state.verification;
    if (media == null ||
        v == null ||
        state.status != VerifiedHostStatus.ready) {
      return;
    }
    emit(
      VerifiedHostState(
        status: VerifiedHostStatus.uploading,
        verification: v,
        uploadingKind: kind,
      ),
    );
    final r = await _repo.uploadEvidence(kind: kind, media: media);
    if (isClosed) return;
    if (r case Err(:final failure)) {
      emit(
        VerifiedHostState(
          status: VerifiedHostStatus.ready,
          verification: v,
          failure: failure,
        ),
      );
      return;
    }
    final fresh = await _repo.getVerification();
    if (isClosed) return;
    emit(
      VerifiedHostState(
        status: VerifiedHostStatus.ready,
        verification: fresh is Success<HostVerification> ? fresh.value : v,
        failure: fresh is Err<HostVerification> ? fresh.failure : null,
      ),
    );
  }

  Future<void> submit() async {
    final v = state.verification;
    if (v == null || !v.readyToSubmit) return;
    emit(
      VerifiedHostState(status: VerifiedHostStatus.submitting, verification: v),
    );
    final key = _submitKey ??= IdempotencyKey.generate();
    final r = await _repo.submit(
      evidenceIds: [for (final e in v.pending) e.id],
      idempotencyKey: key,
    );
    if (isClosed) return;
    emit(switch (r) {
      Success(:final value) => () {
        _submitKey = null;
        return VerifiedHostState(
          status: VerifiedHostStatus.ready,
          verification: value,
          submitted: true,
        );
      }(),
      Err(:final failure) => VerifiedHostState(
        status: VerifiedHostStatus.ready,
        verification: v,
        failure: failure,
      ),
    });
  }
}
