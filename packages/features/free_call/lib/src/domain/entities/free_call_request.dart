import 'package:equatable/equatable.dart';

final class FreeCallRequest extends Equatable {
  const FreeCallRequest({
    required this.requestId,
    required this.status,
    required this.callId,
  });

  final String requestId;

  /// `searching`, `matched`, `no_host_available` or `cancelled`.
  final String status;
  final String? callId;

  bool get isMatched => status == 'matched' && callId != null;
  bool get isSearching => status == 'searching';

  @override
  List<Object?> get props => [requestId, status, callId];
}
