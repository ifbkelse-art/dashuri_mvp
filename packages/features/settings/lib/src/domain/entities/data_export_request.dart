import 'package:equatable/equatable.dart';

final class DataExportRequest extends Equatable {
  const DataExportRequest({required this.requestId, required this.status});

  final String requestId;
  final String status;

  @override
  List<Object?> get props => [requestId, status];
}
