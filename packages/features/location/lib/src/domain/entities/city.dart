import 'package:equatable/equatable.dart';

/// A supported Indian city (coarse location, decision F4).
final class City extends Equatable {
  const City({required this.id, required this.name, required this.state});

  /// Stable slug, e.g. `pune`.
  final String id;
  final String name;

  /// State or union territory, e.g. `Maharashtra`.
  final String state;

  @override
  List<Object?> get props => [id, name, state];
}
