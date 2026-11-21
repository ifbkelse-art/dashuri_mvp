import 'package:equatable/equatable.dart';

/// Short-lived, call-scoped credentials issued by the backend for the video
/// provider. They allow joining exactly one call as exactly one user.
final class CallCredentials extends Equatable {
  const CallCredentials({
    required this.provider,
    required this.providerCallId,
    required this.userToken,
    required this.expiresAt,
    this.apiKey,
    this.providerUserId,
    this.callType,
  });

  final String provider; // e.g. "stream"
  final String providerCallId;
  final String userToken;
  final DateTime expiresAt;

  /// Public provider API key (Stream api key), when the server sends it.
  /// The app falls back to `DASHURI_STREAM_API_KEY` from its build config.
  final String? apiKey;

  /// Provider user id; when absent the adapter reads it from the token.
  final String? providerUserId;

  /// Provider call type, e.g. `default` (joins `<callType>:<providerCallId>`).
  final String? callType;

  @override
  List<Object?> get props => [
    provider,
    providerCallId,
    userToken,
    expiresAt,
    apiKey,
    providerUserId,
    callType,
  ];
}
