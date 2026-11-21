import 'package:equatable/equatable.dart';

final class FreeCallRequest extends Equatable {
  const FreeCallRequest({
    required this.requestId,
    required this.status,
    required this.callId,
  });

  final String requestId;
  final String status;
  final String? callId;

  @override
  List<Object?> get props => [requestId, status, callId];
}
