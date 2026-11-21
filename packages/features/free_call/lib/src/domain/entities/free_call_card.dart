import 'package:equatable/equatable.dart';

final class FreeCallCard extends Equatable {
  const FreeCallCard({required this.status, required this.usedAt});

  /// `available`, `used`, `not_eligible` or `unavailable_on_platform`.
  final String status;
  final DateTime? usedAt;

  bool get isAvailable => status == 'available';

  @override
  List<Object?> get props => [status, usedAt];
}
