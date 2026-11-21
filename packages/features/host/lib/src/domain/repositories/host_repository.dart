import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_call.dart';
import '../entities/host_earnings.dart';
import '../entities/host_photo.dart';
import '../entities/host_profile.dart';
import '../entities/host_status.dart';
import '../entities/kyc_session.dart';
import '../entities/withdrawal.dart';

/// Contract for host data. Implemented in the data layer;
/// use cases depend only on this interface.
abstract interface class HostRepository {
  Future<Result<HostStatus>> getHostStatus();

  Future<Result<HostStatus>> applyAsHost({
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<KycSession>> startKyc({required IdempotencyKey idempotencyKey});

  Future<Result<HostStatus>> setAvailability({required bool isAvailable});

  Future<Result<void>> sendHeartbeat();

  Future<Result<HostStatus>> setRate({required int ratePerMinute});

  Future<Result<HostStatus>> setFreeCallOptIn({required bool optIn});

  Future<Result<HostEarnings>> getEarnings();

  Future<Result<Withdrawal>> requestWithdrawal({
    required int beans,
    required IdempotencyKey idempotencyKey,
  });

  Future<Result<Page<Withdrawal>>> listWithdrawals({required PageRequest page});

  /// GET /v1/me/profile
  Future<Result<HostProfile>> getMyProfile();

  /// PATCH /v1/me/profile
  Future<Result<HostProfile>> updateMyProfile({
    required String displayName,
    required String? bio,
    required List<String> languages,
  });

  /// POST /v1/me/photos/upload-tickets, then PUT the bytes to the signed URL.
  Future<Result<PhotoUploadTicket>> uploadPhoto({
    required PickedPhoto photo,
    required IdempotencyKey idempotencyKey,
  });

  /// GET /v1/calls/history
  Future<Result<Page<HostCall>>> listCallHistory({required PageRequest page});
}
