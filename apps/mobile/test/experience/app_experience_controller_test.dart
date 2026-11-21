import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_mobile/app/experience/app_experience_controller.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('loads per-user choices and persists changes', () async {
    final store = MemoryStore()
      ..values[AppExperienceController.modeKey('u1')] = 'host';
    final c = AppExperienceController(store);
    expect(c.isLoaded, isFalse);
    await c.onSession(
      SessionSignedIn(session: testSession, account: accountWith(host: true)),
    );
    expect(c.isLoaded, isTrue);
    expect(c.mode, ExperienceMode.host);
    expect(c.hostModeAvailable, isTrue);
    expect(c.effectiveMode, ExperienceMode.host);
    expect(c.permissionsPrimerDone, isFalse);

    await c.completePermissionsPrimer();
    await c.setMode(ExperienceMode.customer);
    expect(store.values[AppExperienceController.permissionsKey('u1')], '1');
    expect(store.values[AppExperienceController.modeKey('u1')], 'customer');
    c.dispose();
  });

  test('host mode needs an approved host account', () async {
    final store = MemoryStore()
      ..values[AppExperienceController.modeKey('u1')] = 'host';
    final c = AppExperienceController(store);
    await c.onSession(
      SessionSignedIn(session: testSession, account: accountWith()),
    );
    expect(c.mode, ExperienceMode.host);
    expect(c.effectiveMode, ExperienceMode.customer);
    c.dispose();
  });

  test('signing out forgets the loaded user and notifies', () async {
    final c = AppExperienceController(MemoryStore());
    var notified = 0;
    c.addListener(() => notified++);
    await c.onSession(
      SessionSignedIn(session: testSession, account: accountWith()),
    );
    await c.onSession(const SessionSignedOut());
    expect(c.isLoaded, isFalse);
    expect(c.mode, isNull);
    expect(notified, greaterThanOrEqualTo(3));
    c.dispose();
  });
}
