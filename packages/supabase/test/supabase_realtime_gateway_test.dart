import 'package:dashuri_network/dashuri_network.dart';
import 'package:dashuri_supabase/src/supabase_realtime_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records channel opens/closes and lets a test push broadcasts and
/// report the channel's health.
final class _FakeRealtime {
  final opened = <String>[];
  final closed = <String>[];
  final _sinks = <String, void Function(String, Map<String, Object?>)>{};
  final _links = <String, void Function({required bool up})>{};

  RealtimeChannelOpener get opener => (topic, onEvent, onLink) {
    opened.add(topic);
    _sinks[topic] = onEvent;
    _links[topic] = onLink;
    return () async {
      closed.add(topic);
      _sinks.remove(topic);
    };
  };

  void push(String topic, String type, [Map<String, Object?> p = const {}]) =>
      _sinks[topic]?.call(type, p);

  /// The client gave the channel up (server closed it).
  void drop(String topic) => _links[topic]?.call(up: false);

  void joined(String topic) => _links[topic]?.call(up: true);
}

void main() {
  test(
    'subscribers to the same topic share ONE channel and all get events',
    () async {
      final rt = _FakeRealtime();
      final gw = SupabaseRealtimeGateway.withOpener(rt.opener);
      final chat = <RealtimeEvent>[];
      final wallet = <RealtimeEvent>[];
      final a = gw.subscribe('user:1').listen(chat.add);
      final b = gw.subscribe('user:1').listen(wallet.add);

      rt.push('user:1', 'chat.message', {'conversation_id': 'c1'});
      await Future<void>.delayed(Duration.zero);

      expect(rt.opened, [
        'user:1',
      ], reason: 'a second join would kick the first');
      expect(chat.single.type, 'chat.message');
      expect(chat.single.payload['conversation_id'], 'c1');
      expect(wallet.single.type, 'chat.message');

      await a.cancel();
      expect(rt.closed, isEmpty, reason: 'another subscriber still listens');
      rt.push('user:1', 'wallet.updated');
      await Future<void>.delayed(Duration.zero);
      expect(wallet.length, 2);
      expect(chat.length, 1);

      await b.cancel();
      expect(rt.closed, ['user:1']);
    },
  );

  test('a topic is reopened after everyone left', () async {
    final rt = _FakeRealtime();
    final gw = SupabaseRealtimeGateway.withOpener(rt.opener);
    await gw.subscribe('user:1').listen((_) {}).cancel();
    final got = <RealtimeEvent>[];
    final s = gw.subscribe('user:1').listen(got.add);
    rt.push('user:1', 'chat.read');
    await Future<void>.delayed(Duration.zero);
    expect(rt.opened, ['user:1', 'user:1']);
    expect(got.single.type, 'chat.read');
    await s.cancel();
  });

  test('different topics get their own channels', () async {
    final rt = _FakeRealtime();
    final gw = SupabaseRealtimeGateway.withOpener(rt.opener);
    final s1 = gw.subscribe('user:1').listen((_) {});
    final s2 = gw.subscribe('call:9').listen((_) {});
    expect(rt.opened, ['user:1', 'call:9']);
    await s1.cancel();
    await s2.cancel();
    expect(rt.closed, ['user:1', 'call:9']);
  });

  test(
    'a channel the server closes is reopened and events flow again',
    () async {
      final rt = _FakeRealtime();
      final gw = SupabaseRealtimeGateway.withOpener(
        rt.opener,
        reopenDelay: const Duration(milliseconds: 5),
      );
      final got = <RealtimeEvent>[];
      final s = gw.subscribe('user:1').listen(got.add);
      rt.joined('user:1');

      rt.drop('user:1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rt.opened, ['user:1', 'user:1'], reason: 'reopened once');
      expect(rt.closed, ['user:1'], reason: 'the dead channel was released');

      rt.push('user:1', 'call.updated');
      await Future<void>.delayed(Duration.zero);
      expect(got.single.type, 'call.updated');
      await s.cancel();
    },
  );

  test('no reopen after everyone left', () async {
    final rt = _FakeRealtime();
    final gw = SupabaseRealtimeGateway.withOpener(
      rt.opener,
      reopenDelay: const Duration(milliseconds: 5),
    );
    await gw.subscribe('user:1').listen((_) {}).cancel();
    rt.drop('user:1'); // the close we caused ourselves
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(rt.opened, ['user:1']);
  });

  test('repeated failures back off', () async {
    final rt = _FakeRealtime();
    final gw = SupabaseRealtimeGateway.withOpener(
      rt.opener,
      reopenDelay: const Duration(milliseconds: 20),
      maxReopenDelay: const Duration(milliseconds: 80),
    );
    final s = gw.subscribe('user:1').listen((_) {});
    rt.drop('user:1'); // reopen after 20 ms
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(rt.opened.length, 2);
    rt.drop('user:1'); // second failure: 40 ms
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(rt.opened.length, 2, reason: 'still waiting (backoff)');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(rt.opened.length, 3);
    await s.cancel();
  });
}
