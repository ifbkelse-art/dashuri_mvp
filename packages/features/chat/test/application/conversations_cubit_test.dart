import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListConversations extends Mock implements ListConversations {}

void main() {
  late _MockListConversations useCase;

  setUpAll(() => registerFallbackValue(const PageRequest()));
  setUp(() => useCase = _MockListConversations());

  blocTest<ConversationsCubit, ConversationsState>(
    'emits Loading then Failed when the use case fails',
    setUp: () => when(
      () => useCase(any()),
    ).thenAnswer((_) async => const Err<Page<Conversation>>(NetworkFailure())),
    build: () => ConversationsCubit(useCase),
    act: (cubit) => cubit.load(),
    expect: () => const <ConversationsState>[
      ConversationsStateLoading(),
      ConversationsStateFailed(NetworkFailure()),
    ],
  );
}
