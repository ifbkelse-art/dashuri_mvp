import 'package:bloc_test/bloc_test.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:mocktail/mocktail.dart';

class MockListInbox extends Mock implements ListInbox {}

class MockMarkRead extends Mock implements MarkRead {}

class MockWatchNewNotifications extends Mock implements WatchNewNotifications {}

class MockRealtimeGateway extends Mock implements RealtimeGateway {}

class MockSessionGateway extends Mock implements SessionGateway {}

class MockInboxCubit extends MockCubit<InboxState> implements InboxCubit {}

class FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 11, 21, 12);
}

InboxItem item(
  String id, {
  DateTime? at,
  bool read = false,
  String kind = 'purchase.credited',
}) => InboxItem(
  id: id,
  kind: kind,
  title: 'Diamonds added',
  body: '54,000 Diamonds were added to your wallet.',
  createdAt: at ?? DateTime.utc(2026, 11, 21, 11, 58),
  readAt: read ? DateTime.utc(2026, 11, 21) : null,
);
