import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetHostStatus extends Mock implements GetHostStatus {}

void main() {
  late _MockGetHostStatus useCase;

  setUpAll(() => registerFallbackValue(const NoInput()));
  setUp(() => useCase = _MockGetHostStatus());

  blocTest<HostDashboardCubit, HostDashboardState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<HostStatus>(NetworkFailure())),
    build: () => HostDashboardCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <HostDashboardState>[
      HostDashboardStateLoading(),
      HostDashboardStateFailed(NetworkFailure()),
    ],
  );
}
