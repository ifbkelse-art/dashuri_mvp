import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_earnings.dart';
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
}
