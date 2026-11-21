import 'package:equatable/equatable.dart';

final class BlockedUser extends Equatable {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final DateTime blockedAt;

  @override
  List<Object?> get props => [userId, displayName, blockedAt];
}
