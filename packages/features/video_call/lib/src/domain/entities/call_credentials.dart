import 'package:equatable/equatable.dart';

/// Short-lived, call-scoped credentials issued by the backend for the video
/// provider. They allow joining exactly one call as exactly one user.
final class CallCredentials extends Equatable {
  const CallCredentials({
    required this.provider,
    required this.providerCallId,
    required this.userToken,
    required this.expiresAt,
  });

  final String provider; // e.g. "stream"
  final String providerCallId;
  final String userToken;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [provider, providerCallId, userToken, expiresAt];
}
