import 'package:equatable/equatable.dart';

final class MessagingPrivacy extends Equatable {
  const MessagingPrivacy({required this.whoCanMessage});

  final String whoCanMessage;

  @override
  List<Object?> get props => [whoCanMessage];
}
