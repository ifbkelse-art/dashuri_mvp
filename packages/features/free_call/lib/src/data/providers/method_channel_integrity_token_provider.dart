import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/services.dart';

import '../../domain/ports/integrity_token_provider.dart';

/// `MethodChannel('dashuri/integrity')`, method `requestToken`. The app's
/// Android side (integrator) calls the Play Integrity API and derives the
/// nonce natively, so no arguments are sent.
final class MethodChannelIntegrityTokenProvider
    implements IntegrityTokenProvider {
  const MethodChannelIntegrityTokenProvider({
    MethodChannel channel = const MethodChannel('dashuri/integrity'),
  }) : _channel = channel;

  final MethodChannel _channel;

  static const _unavailable = 'integrity_unavailable';

  @override
  Future<Result<String>> requestToken() async {
    try {
      final token = await _channel.invokeMethod<String>('requestToken');
      if (token == null || token.isEmpty) {
        return const Err(
          PlatformFailure(code: _unavailable, message: 'empty token'),
        );
      }
      return Success(token);
    } on MissingPluginException catch (e) {
      return Err(PlatformFailure(code: _unavailable, message: e.message));
    } on PlatformException catch (e) {
      return Err(
        PlatformFailure(code: _unavailable, message: '${e.code}: ${e.message}'),
      );
    }
  }
}
