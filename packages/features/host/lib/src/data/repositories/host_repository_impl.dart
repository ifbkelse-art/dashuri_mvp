import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/host_call.dart';
import '../../domain/entities/host_earnings.dart';
import '../../domain/entities/host_photo.dart';
import '../../domain/entities/host_profile.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/entities/kyc_session.dart';
import '../../domain/entities/withdrawal.dart';
import '../../domain/repositories/host_repository.dart';
import '../datasources/host_profile_remote_data_source.dart';
import '../datasources/host_remote_data_source.dart';
import '../datasources/photo_upload_data_source.dart';

/// Default [HostRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class HostRepositoryImpl implements HostRepository {
  const HostRepositoryImpl(this._remote, this._profile, this._photos);

  final HostRemoteDataSource _remote;
  final HostProfileRemoteDataSource _profile;
  final PhotoUploadDataSource _photos;

  /// A user who never applied has no host row; the server may answer 404.
  @override
  Future<Result<HostStatus>> getHostStatus() async {
    final result = await _remote.getHostStatus();
    return switch (result) {
      Err(failure: NotFoundFailure()) => const Success(HostStatus.notApplied),
      _ => result,
    };
  }

  @override
  Future<Result<HostStatus>> applyAsHost({
    required IdempotencyKey idempotencyKey,
  }) => _remote.applyAsHost(idempotencyKey: idempotencyKey);

  @override
  Future<Result<KycSession>> startKyc({
    required IdempotencyKey idempotencyKey,
  }) => _remote.startKyc(idempotencyKey: idempotencyKey);

  @override
  Future<Result<HostStatus>> setAvailability({required bool isAvailable}) =>
      _remote.setAvailability(isAvailable: isAvailable);

  @override
  Future<Result<void>> sendHeartbeat() => _remote.sendHeartbeat();

  @override
  Future<Result<HostStatus>> setRate({required int ratePerMinute}) =>
      _remote.setRate(ratePerMinute: ratePerMinute);

  @override
  Future<Result<HostStatus>> setFreeCallOptIn({required bool optIn}) =>
      _remote.setFreeCallOptIn(optIn: optIn);

  @override
  Future<Result<HostEarnings>> getEarnings() => _remote.getEarnings();

  @override
  Future<Result<Withdrawal>> requestWithdrawal({
    required int beans,
    required IdempotencyKey idempotencyKey,
  }) => _remote.requestWithdrawal(beans: beans, idempotencyKey: idempotencyKey);

  @override
  Future<Result<Page<Withdrawal>>> listWithdrawals({
    required PageRequest page,
  }) => _remote.listWithdrawals(page: page);

  @override
  Future<Result<HostProfile>> getMyProfile() => _profile.getMyProfile();

  @override
  Future<Result<HostProfile>> updateMyProfile({
    required String displayName,
    required String? bio,
    required List<String> languages,
  }) => _profile.updateMyProfile(
    displayName: displayName,
    bio: bio,
    languages: languages,
  );

  @override
  Future<Result<PhotoUploadTicket>> uploadPhoto({
    required PickedPhoto photo,
    required IdempotencyKey idempotencyKey,
  }) async {
    final ticket = await _profile.requestPhotoUpload(
      contentType: photo.contentType,
      idempotencyKey: idempotencyKey,
    );
    switch (ticket) {
      case Err(:final failure):
        return Err(failure);
      case Success(:final value):
        final uploaded = await _photos.upload(ticket: value, photo: photo);
        return uploaded.map((_) => value);
    }
  }

  @override
  Future<Result<Page<HostCall>>> listCallHistory({
    required PageRequest page,
  }) => _profile.listCallHistory(page: page);
}
