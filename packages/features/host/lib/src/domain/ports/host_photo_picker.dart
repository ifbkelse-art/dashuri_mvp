import '../entities/host_photo.dart';

/// Lets the user choose a photo. The host feature has no picker dependency,
/// so the app registers an implementation in GetIt (for example backed by
/// the platform photo picker). When none is registered, H09 explains that
/// photos can't be added from this build instead of showing a dead button.
abstract interface class HostPhotoPicker {
  /// Returns null when the user cancels.
  Future<PickedPhoto?> pickPhoto();
}

/// Switches the app from host mode to customer mode (H23). The app shell
/// (FE-core) owns the persisted mode key, so it registers this in GetIt or
/// passes it as route `extra` to [RoutePaths.hostProfileTab].
final class HostModeSwitch {
  const HostModeSwitch(this.switchToCustomer);

  final Future<void> Function() switchToCustomer;
}

/// Enters host mode right after approval: the app re-reads the account (so
/// the router knows the user is now an approved host) and selects host
/// mode. Without it, "Go to host home" bounced back to Discover until the
/// app was restarted. Optional: registered by the app.
final class HostModeEnter {
  const HostModeEnter(this.enter);

  final Future<void> Function() enter;
}
