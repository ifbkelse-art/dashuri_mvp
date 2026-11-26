import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:dashuri_storage/dashuri_storage.dart';
import 'package:dashuri_supabase/dashuri_supabase.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:feature_free_call/feature_free_call.dart';
import 'package:feature_host/feature_host.dart';
import 'package:feature_location/feature_location.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../experience/app_experience_controller.dart';
import '../platform/device_photo_pickers.dart';
import '../platform/device_video_picker.dart';
import 'in_call_chat_adapter.dart';
import 'unconfigured_backend.dart';

/// The app's single service locator. Only this file and route builders use it.
final GetIt sl = GetIt.instance;

/// False when running on [UnconfiguredBackend] (development without config):
/// the welcome page then says the backend is not configured.
bool backendConfigured = true;

/// EXPERIMENT — Reels tab and routes (DASHURI_REELS_ENABLED, default off).
bool reelsEnabled = false;

/// Composition root: platform adapters first, then each feature.
/// To add a feature: depend on it in pubspec.yaml, call its `register…Feature(sl)`
/// here and add its routes in `router/app_router.dart`.
Future<void> configureDependencies(AppConfig config, AppLogger logger) async {
  sl
    ..registerSingleton<AppConfig>(config)
    ..registerSingleton<AppLogger>(logger)
    ..registerSingleton<Clock>(const SystemClock())
    ..registerLazySingleton<KeyValueStore>(
      () => PreferencesStore(SharedPreferencesAsync()),
    )
    ..registerLazySingleton<SecureKeyValueStore>(SecureStore.new);

  sl
    ..registerLazySingleton<AppExperienceController>(
      () => AppExperienceController(sl<KeyValueStore>()),
    )
    ..registerLazySingleton<ExperienceController>(
      () => sl<AppExperienceController>(),
    );

  backendConfigured = config.validate().isEmpty;
  if (backendConfigured) {
    final client = await initSupabase(config);
    final session = SupabaseSessionGateway(client);
    sl
      ..registerSingleton<SessionGateway>(session)
      ..registerSingleton<AccessTokenProvider>(session)
      ..registerSingleton<RealtimeGateway>(SupabaseRealtimeGateway(client));
  } else {
    if (config.environment != AppEnvironment.development) {
      throw StateError(
        'Configuration incomplete for ${config.environment.name}: ${config.validate()}',
      );
    }
    logger.warning(
      'Backend not configured: every API call will fail with backend_not_configured.',
    );
    const backend = UnconfiguredBackend();
    sl
      ..registerSingleton<SessionGateway>(backend)
      ..registerSingleton<AccessTokenProvider>(backend)
      ..registerSingleton<RealtimeGateway>(backend);
  }

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(
      baseUrl: config.apiBaseUrl,
      tokens: sl<AccessTokenProvider>(),
    ),
  );

  registerAuthFeature(sl);
  sl
    ..registerLazySingleton<PhotoPicker>(DevicePhotoPicker.new)
    ..registerLazySingleton<HostPhotoPicker>(DeviceHostPhotoPicker.new)
    ..registerLazySingleton<VerificationMediaPicker>(
      DeviceVerificationMediaPicker.new,
    );
  registerProfileFeature(sl);
  registerDiscoveryFeature(sl);
  registerFreeCallFeature(sl);
  registerVideoCallFeature(sl);
  registerChatFeature(sl);
  registerWalletFeature(sl);
  registerPurchasesFeature(sl, cashfreeEnabled: config.cashfreeEnabled);
  registerHostFeature(sl);
  registerSafetyFeature(sl);
  registerNotificationsFeature(sl);
  registerSettingsFeature(sl);
  registerLocationFeature(sl);

  // EXPERIMENT — Dashuri Reels. Nothing is registered when the flag is off.
  reelsEnabled = config.reelsEnabled;
  if (reelsEnabled) {
    sl.registerLazySingleton<ReelVideoPicker>(DeviceReelVideoPicker.new);
    registerReelsFeature(sl);
  }

  // EXPERIMENT — chat inside video calls (DASHURI_IN_CALL_CHAT_ENABLED,
  // default off). Same conversation as the inbox; see docs/chat.
  if (config.inCallChatEnabled) {
    sl.registerLazySingleton<InCallChat>(() => FeatureChatInCallChat(sl));
  }

  // Virtual gifts (DASHURI_GIFTS_ENABLED, default off; docs/gifts). The call
  // screen, Host Home and the wallet look these up.
  if (config.giftsEnabled) {
    registerVideoCallGifts(sl);
    sl
      ..registerSingleton<HostGiftsEnabled>(const HostGiftsEnabled())
      ..registerSingleton<WalletGiftsEnabled>(const WalletGiftsEnabled());
  }

  // Optional arrival photo when going online (DASHURI_ARRIVAL_PHOTOS_ENABLED,
  // default off; docs/host). Camera only — never the gallery.
  if (config.arrivalPhotosEnabled) {
    sl.registerLazySingleton<ArrivalCamera>(DeviceArrivalCamera.new);
  }

  // UI/UX pass: after host approval, "Go to host home" re-reads the account
  // and selects host mode (no app restart needed).
  sl.registerLazySingleton<HostModeEnter>(
    () => HostModeEnter(() async {
      await sl<SessionCubit>().refreshAccountQuietly();
      await sl<ExperienceController>().setMode(ExperienceMode.host);
    }),
  );

  // A ring for a host is normally pushed over realtime; while the host is
  // online with the app open, the call feature also checks for ringing calls
  // every few seconds so a missed message cannot lose a call.
  sl.registerLazySingleton<IncomingCallCheckGate>(
    () => IncomingCallCheckGate(() {
      final presence = sl<HostPresenceController>();
      return presence.isOnline && presence.isInForeground;
    }),
  );

  // H23 "Switch to customer mode" (feature_host looks this up if present).
  sl.registerLazySingleton<HostModeSwitch>(
    () => HostModeSwitch(
      () => sl<ExperienceController>().setMode(ExperienceMode.customer),
    ),
  );
}
