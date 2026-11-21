import 'package:equatable/equatable.dart';

final class FreeCallCard extends Equatable {
  const FreeCallCard({required this.status, required this.usedAt});

  final String status;
  final DateTime? usedAt;

  @override
  List<Object?> get props => [status, usedAt];
}
