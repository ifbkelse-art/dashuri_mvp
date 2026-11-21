import 'package:equatable/equatable.dart';

/// The signed-in user's session as the app sees it. Roles and eligibility
/// come from the Go API (`GET /v1/me`), not from token claims on the client.
final class AuthSession extends Equatable {
  const AuthSession({required this.userId, required this.expiresAt});

  final String userId;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [userId, expiresAt];
}
