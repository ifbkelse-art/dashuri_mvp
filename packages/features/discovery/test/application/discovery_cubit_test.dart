import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListAvailableHosts extends Mock implements ListAvailableHosts {}

void main() {
  late _MockListAvailableHosts useCase;

  setUpAll(() => registerFallbackValue(const PageRequest()));
  setUp(() => useCase = _MockListAvailableHosts());

  blocTest<DiscoveryCubit, DiscoveryState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Page<HostCard>>(NetworkFailure())),
    build: () => DiscoveryCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <DiscoveryState>[
      DiscoveryStateLoading(),
      DiscoveryStateFailed(NetworkFailure()),
    ],
  );
}
