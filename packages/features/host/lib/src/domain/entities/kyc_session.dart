import 'package:equatable/equatable.dart';

final class KycSession extends Equatable {
  const KycSession({required this.sessionId, required this.redirectUrl});

  final String sessionId;
  final String? redirectUrl;

  @override
  List<Object?> get props => [sessionId, redirectUrl];
}
