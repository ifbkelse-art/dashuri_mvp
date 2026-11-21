import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_earnings.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/entities/kyc_session.dart';
import '../../domain/entities/withdrawal.dart';
import '../models/host_earnings_json.dart';
import '../models/host_status_json.dart';
import '../models/kyc_session_json.dart';
import '../models/withdrawal_json.dart';

/// HTTP access to the host endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class HostRemoteDataSource {
  const HostRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<HostStatus>> getHostStatus() =>
      _api.get('/v1/host', decode: objectDecoder(hostStatusFromJson));

  Future<Result<HostStatus>> applyAsHost({
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/host/application',
    decode: objectDecoder(hostStatusFromJson),
    idempotencyKey: idempotencyKey,
  );

  Future<Result<KycSession>> startKyc({
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/host/kyc/sessions',
    decode: objectDecoder(kycSessionFromJson),
    idempotencyKey: idempotencyKey,
  );

  Future<Result<HostStatus>> setAvailability({required bool isAvailable}) =>
      _api.put(
        '/v1/host/availability',
        decode: objectDecoder(hostStatusFromJson),
        body: {'is_available': isAvailable},
      );

  Future<Result<void>> sendHeartbeat() =>
      _api.post('/v1/host/availability/heartbeat', decode: (_) {});

  Future<Result<HostStatus>> setRate({required int ratePerMinute}) => _api.put(
    '/v1/host/rate',
    decode: objectDecoder(hostStatusFromJson),
    body: {'rate_per_minute': ratePerMinute},
  );

  Future<Result<HostStatus>> setFreeCallOptIn({required bool optIn}) =>
      _api.put(
        '/v1/host/free-call-opt-in',
        decode: objectDecoder(hostStatusFromJson),
        body: {'opt_in': optIn},
      );

  Future<Result<HostEarnings>> getEarnings() => _api.get(
    '/v1/host/earnings',
    decode: objectDecoder(hostEarningsFromJson),
  );

  Future<Result<Withdrawal>> requestWithdrawal({
    required int beans,
    required IdempotencyKey idempotencyKey,
  }) => _api.post(
    '/v1/host/withdrawals',
    decode: objectDecoder(withdrawalFromJson),
    body: {'beans': beans},
    idempotencyKey: idempotencyKey,
  );

  Future<Result<Page<Withdrawal>>> listWithdrawals({
    required PageRequest page,
  }) => _api.get(
    '/v1/host/withdrawals',
    decode: pageDecoder(withdrawalFromJson),
    query: page.toQuery(),
  );
}
