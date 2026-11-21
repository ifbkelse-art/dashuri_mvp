import 'package:equatable/equatable.dart';

final class InboxItem extends Equatable {
  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  @override
  List<Object?> get props => [id, kind, title, body, createdAt, readAt];
}
