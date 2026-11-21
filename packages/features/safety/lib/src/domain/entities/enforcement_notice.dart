import 'package:equatable/equatable.dart';

final class EnforcementNotice extends Equatable {
  const EnforcementNotice({
    required this.id,
    required this.action,
    required this.reason,
    required this.createdAt,
    required this.appealable,
  });

  final String id;
  final String action;
  final String reason;
  final DateTime createdAt;
  final bool appealable;

  @override
  List<Object?> get props => [id, action, reason, createdAt, appealable];
}
