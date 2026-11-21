import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListInbox extends Mock implements ListInbox {}

void main() {
  late _MockListInbox useCase;

  setUpAll(() => registerFallbackValue(const PageRequest()));
  setUp(() => useCase = _MockListInbox());

  blocTest<InboxCubit, InboxState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Page<InboxItem>>(NetworkFailure())),
    build: () => InboxCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <InboxState>[
      InboxStateLoading(),
      InboxStateFailed(NetworkFailure()),
    ],
  );
}
