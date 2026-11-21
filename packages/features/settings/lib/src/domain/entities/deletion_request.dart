import 'package:equatable/equatable.dart';

final class DeletionRequest extends Equatable {
  const DeletionRequest({
    required this.requestId,
    required this.status,
    required this.scheduledFor,
  });

  final String requestId;
  final String status;
  final DateTime? scheduledFor;

  @override
  List<Object?> get props => [requestId, status, scheduledFor];
}
