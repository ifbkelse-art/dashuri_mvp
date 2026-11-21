import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/host_earnings.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/entities/kyc_session.dart';
import '../../domain/entities/withdrawal.dart';
import '../../domain/repositories/host_repository.dart';
import '../datasources/host_remote_data_source.dart';

/// Default [HostRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class HostRepositoryImpl implements HostRepository {
  const HostRepositoryImpl(this._remote);

  final HostRemoteDataSource _remote;

  @override
  Future<Result<HostStatus>> getHostStatus() => _remote.getHostStatus();

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
}
