import 'package:dashuri_network/dashuri_network.dart';
import 'package:dashuri_supabase/src/supabase_realtime_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records channel opens/closes and lets a test push broadcasts.
final class _FakeRealtime {
  final opened = <String>[];
  final closed = <String>[];
  final _sinks = <String, void Function(String, Map<String, Object?>)>{};

  RealtimeChannelOpener get opener => (topic, onEvent) {
    opened.add(topic);
    _sinks[topic] = onEvent;
    return () async {
      closed.add(topic);
      _sinks.remove(topic);
    };
  };

  void push(String topic, String type, [Map<String, Object?> p = const {}]) =>
      _sinks[topic]?.call(type, p);
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
}
