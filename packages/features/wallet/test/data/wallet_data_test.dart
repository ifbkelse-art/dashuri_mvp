import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:feature_wallet/src/data/datasources/wallet_remote_data_source.dart';
import 'package:feature_wallet/src/data/models/wallet_entry_json.dart';
import 'package:feature_wallet/src/data/models/wallet_summary_json.dart';
import 'package:feature_wallet/src/data/repositories/wallet_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Remote extends Mock implements WalletRemoteDataSource {}

class _Session extends Mock implements SessionGateway {}

class _Realtime implements RealtimeGateway {
  // ignore: close_sinks, closed in tearDown.
  final controller = StreamController<RealtimeEvent>.broadcast();
  final channels = <String>[];

  @override
  Stream<RealtimeEvent> subscribe(String channel) {
    channels.add(channel);
    return controller.stream;
  }
}

WalletEntry entry(String id) => WalletEntry(
  id: id,
  currency: 'DIAMOND',
  kind: 'purchase_credit',
  amount: 1,
  createdAt: DateTime.utc(2026),
  reference: null,
);

void main() {
  setUpAll(() => registerFallbackValue(const PageRequest()));

  test('maps WalletSummary and WalletEntry JSON', () {
    final s = walletSummaryFromJson({
      'purchased_diamonds': 10,
      'promotional_diamonds': 2,
      'reserved_diamonds': 1,
      'available_diamonds': 11,
      'beans_on_hold': 3,
      'beans_available': 4,
      'beans_pending_payout': 5,
    });
    expect(s.availableDiamonds, 11);
    expect(s.beansPendingPayout, 5);
    final e = walletEntryFromJson({
      'id': 'e1',
      'currency': 'BEAN',
      'kind': 'call_settlement',
      'amount': 2599,
      'created_at': '2026-11-19T15:01:00Z',
    });
    expect(e.reference, isNull);
    expect(e.createdAt, DateTime.utc(2026, 11, 19, 15, 1));
  });

  group('WalletRepositoryImpl', () {
    late _Remote remote;
    late _Session session;
    late _Realtime realtime;
    late WalletRepositoryImpl repo;

    setUp(() {
      remote = _Remote();
      session = _Session();
      realtime = _Realtime();
      repo = WalletRepositoryImpl(remote, realtime: realtime, session: session);
    });
    tearDown(() => realtime.controller.close());

    test('findWalletEntry scans pages until it finds the id', () async {
      when(() => remote.listWalletEntries(page: any(named: 'page'))).thenAnswer(
        (inv) async {
          final p = inv.namedArguments[#page] as PageRequest;
          return p.cursor == null
              ? Success(Page(items: [entry('a')], nextCursor: 'c'))
              : Success(Page(items: [entry('b')]));
        },
      );
      final r = await repo.findWalletEntry('b');
      expect((r as Success<WalletEntry>).value.id, 'b');
    });

    test('findWalletEntry returns not found after the last page', () async {
      when(
        () => remote.listWalletEntries(page: any(named: 'page')),
      ).thenAnswer((_) async => Success(Page(items: [entry('a')])));
      final r = await repo.findWalletEntry('zzz');
      expect((r as Err<WalletEntry>).failure, const NotFoundFailure());
    });

    test(
      'walletUpdates listens on user:<id> and filters wallet.updated',
      () async {
        when(
          () => session.currentSession,
        ).thenReturn(AuthSession(userId: 'u1', expiresAt: DateTime.utc(2030)));
        final hits = <void>[];
        final sub = repo.walletUpdates().listen(hits.add);
        realtime.controller
          ..add(
            const RealtimeEvent(
              channel: 'user:u1',
              type: 'chat.message',
              payload: {},
            ),
          )
          ..add(
            const RealtimeEvent(
              channel: 'user:u1',
              type: 'wallet.updated',
              payload: {},
            ),
          );
        await Future<void>.delayed(Duration.zero);
        expect(realtime.channels, ['user:u1']);
        expect(hits, hasLength(1));
        await sub.cancel();
      },
    );

    test('walletUpdates is empty when signed out', () async {
      when(() => session.currentSession).thenReturn(null);
      expect(await repo.walletUpdates().isEmpty, isTrue);
    });
  });
}
