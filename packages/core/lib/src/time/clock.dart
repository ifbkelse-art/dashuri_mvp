/// Injectable time source so tests control "now". Display only: billing
/// time is measured by the server, never by the client clock.
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
