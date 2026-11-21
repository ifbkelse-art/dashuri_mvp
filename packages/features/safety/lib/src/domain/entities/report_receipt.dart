import 'package:equatable/equatable.dart';

final class ReportReceipt extends Equatable {
  const ReportReceipt({required this.reportId, required this.status});

  final String reportId;
  final String status;

  @override
  List<Object?> get props => [reportId, status];
}
