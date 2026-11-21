/// Which role shell the user sees (design FL06). One account can be both a
/// customer and a host (D-04); the host shell is used only when the account
/// is an approved host AND the user picked [host].
enum ExperienceMode { customer, host }

/// Device-local onboarding progress and the chosen experience, kept per
/// signed-in user. Implemented by the app (backed by `KeyValueStore`) and
/// injected into features that need to read or change it.
///
/// Server-side onboarding state (age, profile, rules) lives in
/// `GET /v1/me`; only the permissions primer (A14) and the experience choice
/// (A12) are local.
abstract interface class ExperienceController {
  /// False until the preferences for the current user have been read.
  bool get isLoaded;

  /// True once the permissions primer (A14) was completed or skipped.
  bool get permissionsPrimerDone;

  /// Null until the user picked an experience (A12).
  ExperienceMode? get mode;

  /// True when the account is an approved host, so host mode can be used.
  bool get hostModeAvailable;

  /// The shell actually shown: host only if [mode] is host and
  /// [hostModeAvailable].
  ExperienceMode get effectiveMode;

  /// Emits whenever any value above changes.
  Stream<void> get changes;

  Future<void> completePermissionsPrimer();

  Future<void> setMode(ExperienceMode mode);
}

/// Re-reads the account status (`GET /v1/me`) so route guards see the result
/// of an onboarding step (age declaration, profile, rules acceptance).
abstract interface class AccountStatusRefresher {
  Future<void> refreshAccountStatus();
}
