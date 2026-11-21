import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_storage/dashuri_storage.dart';
import 'package:feature_auth/feature_auth.dart';

final testSession = AuthSession(userId: 'u1', expiresAt: DateTime.utc(2030));

AccountStatus accountWith({
  bool age = true,
  bool profile = true,
  bool rules = true,
  bool host = false,
  String? restriction,
}) => AccountStatus(
  userId: 'u1',
  ageEligible: age,
  isHost: host,
  restriction: restriction,
  profileComplete: profile,
  rulesAccepted: rules,
  hostState: host ? 'approved' : null,
);

/// Hand-written fake (the app has no mocking dependency).
final class FakeExperience implements ExperienceController {
  FakeExperience({
    this.isLoaded = true,
    this.permissionsPrimerDone = true,
    this.mode = ExperienceMode.customer,
    this.hostModeAvailable = false,
  });

  @override
  bool isLoaded;
  @override
  bool permissionsPrimerDone;
  @override
  ExperienceMode? mode;
  @override
  bool hostModeAvailable;

  final _changes = StreamController<void>.broadcast();

  @override
  ExperienceMode get effectiveMode =>
      mode == ExperienceMode.host && hostModeAvailable
      ? ExperienceMode.host
      : ExperienceMode.customer;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> completePermissionsPrimer() async {
    permissionsPrimerDone = true;
    _changes.add(null);
  }

  @override
  Future<void> setMode(ExperienceMode m) async {
    mode = m;
    _changes.add(null);
  }
}

final class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// AuthRepository whose session stream the test drives.
final class FakeAuthRepository implements AuthRepository {
  final sessions = StreamController<AuthSession?>.broadcast();
  Result<AccountStatus> account = Success(accountWith());

  @override
  Future<Result<AccountStatus>> acceptCommunityRules(String version) async =>
      account;

  @override
  Future<Result<AccountStatus>> getAccountStatus() async => account;

  @override
  Future<Result<void>> requestOtp(String e164Phone) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async {
    sessions.add(null);
    return const Success(null);
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String e164Phone,
    required String code,
  }) async => Success(testSession);

  @override
  Stream<AuthSession?> watchSession() => sessions.stream;
}
