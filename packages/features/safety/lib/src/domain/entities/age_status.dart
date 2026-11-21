import 'package:equatable/equatable.dart';

final class AgeStatus extends Equatable {
  const AgeStatus({required this.eligible, required this.method});

  final bool eligible;
  final String? method;

  @override
  List<Object?> get props => [eligible, method];
}
