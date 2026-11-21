import 'package:equatable/equatable.dart';

final class AppealReceipt extends Equatable {
  const AppealReceipt({required this.appealId, required this.status});

  final String appealId;
  final String status;

  @override
  List<Object?> get props => [appealId, status];
}
