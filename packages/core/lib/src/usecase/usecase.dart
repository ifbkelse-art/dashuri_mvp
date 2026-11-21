import '../result/result.dart';

/// One application action. Use cases hold no state, depend only on
/// repository contracts, and are registered as factories in DI.
abstract interface class UseCase<Output, Input> {
  Future<Result<Output>> call(Input input);
}

/// Use cases that emit over time (realtime state, purchase updates).
abstract interface class StreamUseCase<Output, Input> {
  Stream<Output> call(Input input);
}

/// Input for use cases that take no parameters.
final class NoInput {
  const NoInput();
}
