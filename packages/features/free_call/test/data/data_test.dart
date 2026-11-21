import 'package:dashuri_core/dashuri_core.dart';
import 'package:feature_free_call/src/data/models/free_call_card_json.dart';
import 'package:feature_free_call/src/data/models/free_call_request_json.dart';
import 'package:feature_free_call/src/data/providers/method_channel_integrity_token_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dashuri/integrity');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('models', () {
    final card = freeCallCardFromJson({'status': 'available'});
    expect(card.isAvailable, isTrue);
    final r = freeCallRequestFromJson({
      'request_id': 'r',
      'status': 'matched',
      'call_id': 'c',
    });
    expect(r.isMatched, isTrue);
  });

  test('integrity token via the method channel, no arguments', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return 'tok';
    });
    final r = await const MethodChannelIntegrityTokenProvider().requestToken();
    expect((r as Success<String>).value, 'tok');
    expect(seen?.method, 'requestToken');
    expect(seen?.arguments, isNull);
  });

  test('missing plugin → integrity_unavailable', () async {
    final r = await const MethodChannelIntegrityTokenProvider().requestToken();
    expect((r as Err).failure.code, 'integrity_unavailable');
  });

  test('platform error → integrity_unavailable', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'API_NOT_AVAILABLE'),
    );
    final r = await const MethodChannelIntegrityTokenProvider().requestToken();
    expect((r as Err).failure, isA<PlatformFailure>());
    expect((r as Err).failure.code, 'integrity_unavailable');
  });
}
