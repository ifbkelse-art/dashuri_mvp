import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' as sv;

import '../../../domain/entities/call_credentials.dart';
import '../../../domain/entities/media_event.dart';
import '../../../domain/ports/video_engine.dart';
import '../../models/call_json.dart';

/// Stream Video adapter for [VideoEngine] (ADR-005, F2).
///
/// One instance per call (registered as a DI factory). It creates a
/// non-singleton `StreamVideo` client with the call-scoped token from the Go
/// API, joins `default:<providerCallId>` with camera and microphone on, maps
/// the SDK call state to [MediaEvent]s and tears everything down on [leave].
final class StreamVideoEngine implements VideoEngine {
  StreamVideoEngine({String fallbackApiKey = ''})
    : _fallbackApiKey = fallbackApiKey;

  final String _fallbackApiKey;
  sv.StreamVideo? _client;
  StreamSubscription<sv.CallState>? _stateSub;
  final _events = StreamController<MediaEvent>.broadcast();

  /// The joined Stream call; video views and frame capture listen to it.
  final ValueNotifier<sv.Call?> call = ValueNotifier(null);

  bool _lost = false;
  bool _remoteSeen = false;
  bool _remoteVideo = false;

  @override
  Future<Result<void>> join(CallCredentials credentials) async {
    if (credentials.provider != 'stream') {
      return Err(
        PlatformFailure(
          code: 'video_provider_unsupported',
          message: credentials.provider,
        ),
      );
    }
    final apiKey = credentials.apiKey ?? _fallbackApiKey;
    if (apiKey.isEmpty) {
      return const Err(
        PlatformFailure(
          code: 'video_not_configured',
          message:
              'No Stream api key (server api_key or DASHURI_STREAM_API_KEY)',
        ),
      );
    }
    final userId =
        credentials.providerUserId ?? userIdFromJwt(credentials.userToken);
    if (userId == null) {
      return const Err(PlatformFailure(code: 'video_credentials_invalid'));
    }
    if (call.value != null) return const Success(null);
    try {
      final client = sv.StreamVideo.create(
        apiKey,
        user: sv.User.regular(userId: userId),
        userToken: credentials.userToken,
        options: sv.StreamVideoOptions(autoConnect: false),
      );
      _client = client;
      final connected = await client.connect();
      if (connected.isFailure) {
        await _teardown();
        return Err(_failure('video_connect_failed', connected));
      }
      var (type, id) = _callCid(credentials.providerCallId);
      if (credentials.callType != null &&
          !credentials.providerCallId.contains(':')) {
        type = credentials.callType!;
      }
      final c = client.makeCall(
        callType: sv.StreamCallType.fromString(type),
        id: id,
      );
      final joined = await c.join(
        connectOptions: sv.CallConnectOptions(
          camera: sv.TrackOption.enabled(),
          microphone: sv.TrackOption.enabled(),
        ),
      );
      if (joined.isFailure) {
        await _teardown();
        return Err(_failure('video_join_failed', joined));
      }
      call.value = c;
      _stateSub = c.state.valueStream.listen(_onState);
      _events.add(MediaEvent.joined);
      return const Success(null);
    } on Object catch (e) {
      await _teardown();
      return Err(PlatformFailure(code: 'video_join_failed', message: '$e'));
    }
  }

  /// `default:abc` → ('default', 'abc'); a bare id uses the default type.
  static (String, String) _callCid(String providerCallId) {
    final i = providerCallId.indexOf(':');
    return i <= 0
        ? ('default', providerCallId)
        : (providerCallId.substring(0, i), providerCallId.substring(i + 1));
  }

  static PlatformFailure _failure(String code, sv.Result<Object?> r) =>
      PlatformFailure(
        code: code,
        message: r is sv.Failure ? r.error.message : null,
      );

  void _onState(sv.CallState s) {
    final status = s.status;
    if (status is sv.CallStatusReconnecting ||
        status is sv.CallStatusMigrating) {
      if (!_lost) {
        _lost = true;
        _events.add(MediaEvent.connectionLost);
      }
    } else if (status is sv.CallStatusConnected ||
        status is sv.CallStatusJoined) {
      if (_lost) {
        _lost = false;
        _events.add(MediaEvent.connectionRestored);
      }
    } else if (status is sv.CallStatusReconnectionFailed) {
      if (!_lost) {
        _lost = true;
        _events.add(MediaEvent.connectionLost);
      }
    } else if (status is sv.CallStatusDisconnected) {
      _events.add(MediaEvent.left);
    }
    final remote = s.otherParticipants;
    if (remote.isNotEmpty && !_remoteSeen) {
      _remoteSeen = true;
      _events.add(MediaEvent.remoteJoined);
    } else if (remote.isEmpty && _remoteSeen) {
      _remoteSeen = false;
      _events.add(MediaEvent.remoteLeft);
    }
    final video = remote.any((p) => p.isVideoEnabled);
    if (video != _remoteVideo) {
      _remoteVideo = video;
      _events.add(
        video ? MediaEvent.remoteVideoStarted : MediaEvent.remoteVideoStopped,
      );
    }
  }

  @override
  Future<void> leave() => _teardown();

  Future<void> _teardown() async {
    await _stateSub?.cancel();
    _stateSub = null;
    final c = call.value;
    call.value = null;
    final client = _client;
    _client = null;
    try {
      if (c != null) await c.leave();
      if (client != null) {
        await client.disconnect();
        await client.dispose();
      }
    } on Object {
      // Best effort: the server ends calls on provider timeouts anyway.
    }
    _lost = _remoteSeen = _remoteVideo = false;
  }

  @override
  Future<void> setMicrophoneEnabled({required bool enabled}) async {
    await call.value?.setMicrophoneEnabled(enabled: enabled);
  }

  @override
  Future<void> setCameraEnabled({required bool enabled}) async {
    await call.value?.setCameraEnabled(enabled: enabled);
  }

  @override
  Future<void> flipCamera() async {
    await call.value?.flipCamera();
  }

  @override
  Stream<MediaEvent> events() => _events.stream;
}
