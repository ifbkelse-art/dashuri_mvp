import 'package:equatable/equatable.dart';

final class ConsentState extends Equatable {
  const ConsentState({
    required this.analytics,
    required this.marketing,
    required this.updatedAt,
  });

  final bool analytics;
  final bool marketing;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [analytics, marketing, updatedAt];
}
