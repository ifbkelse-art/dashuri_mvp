import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

final class _Tokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => null;
}

void main() {
  test(
    'registerHostFeature wires every cubit and one presence controller',
    () async {
      final sl = GetIt.asNewInstance()
        ..registerSingleton<ApiClient>(
          ApiClient(
            baseUrl: Uri.parse('http://127.0.0.1:1'),
            tokens: _Tokens(),
          ),
        );
      registerHostFeature(sl);
      expect(sl<HostDashboardCubit>(), isA<HostDashboardCubit>());
      expect(sl<HostApplicationCubit>(), isA<HostApplicationCubit>());
      expect(sl<HostVerificationCubit>(), isA<HostVerificationCubit>());
      expect(sl<HostProfileSetupCubit>(), isA<HostProfileSetupCubit>());
      expect(sl<HostRateCubit>(), isA<HostRateCubit>());
      expect(sl<HostEarningsCubit>(), isA<HostEarningsCubit>());
      expect(sl<HostWithdrawCubit>(), isA<HostWithdrawCubit>());
      expect(sl<HostPayoutsCubit>(), isA<HostPayoutsCubit>());
      expect(sl<HostCallsCubit>(), isA<HostCallsCubit>());
      expect(sl<HostProfileTabCubit>(), isA<HostProfileTabCubit>());
      expect(
        identical(sl<HostPresenceController>(), sl<HostPresenceController>()),
        isTrue,
      );
      await sl.reset();
    },
  );
}
