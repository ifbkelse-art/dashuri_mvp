import 'package:equatable/equatable.dart';

/// Cursor-based page, matching the API's `{items, next_cursor}` envelope.
final class Page<T> extends Equatable {
  const Page({required this.items, this.nextCursor});

  final List<T> items;

  /// Opaque cursor for the next page; null when this is the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items, nextCursor];
}

final class PageRequest extends Equatable {
  const PageRequest({this.cursor, this.limit = 20});

  final String? cursor;
  final int limit;

  Map<String, String> toQuery() => {'limit': '$limit', 'cursor': ?cursor};

  @override
  List<Object?> get props => [cursor, limit];
}
