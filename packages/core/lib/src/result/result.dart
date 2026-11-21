import '../errors/failure.dart';

/// Outcome of any operation that can fail in an expected way.
///
/// Repositories and use cases return [Result] instead of throwing, so the
/// application layer (BLoCs) handles failure explicitly with `switch`.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  /// Maps the success value; failures pass through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Success<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Runs [onSuccess] or [onFailure] and returns its value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Err<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
