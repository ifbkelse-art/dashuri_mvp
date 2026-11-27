import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/creator_profile.dart';
import '../domain/entities/reel.dart';
import '../domain/ports/reel_video_picker.dart';
import '../domain/usecases/reels_usecases.dart';
import 'reels_feed_cubit.dart' show reelsFailureMessage;

sealed class ReelUploadState extends Equatable {
  const ReelUploadState();
  @override
  List<Object?> get props => [];
}

final class UploadLoading extends ReelUploadState {
  const UploadLoading();
}

/// Upload is impossible here: server says so, or no camera/gallery access.
final class UploadUnavailable extends ReelUploadState {
  const UploadUnavailable(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// R1/R2: choose record or gallery. [error] explains a rejected pick.
final class UploadPick extends ReelUploadState {
  const UploadPick(this.config, {this.error});
  final ReelsConfig config;
  final String? error;
  @override
  List<Object?> get props => [config, error];
}

/// R3/R4: preview facts and caption.
final class UploadPreview extends ReelUploadState {
  const UploadPreview(this.config, this.video, this.durationMs, {this.error});
  final ReelsConfig config;
  final PickedVideo video;
  final int durationMs;
  final String? error;
  @override
  List<Object?> get props => [config, video, durationMs, error];
}

/// R5: bytes going up. [progress] is 0–1.
final class UploadSending extends ReelUploadState {
  const UploadSending(this.progress);
  final double progress;
  @override
  List<Object?> get props => [progress];
}

/// R6/R7: the server owns the reel now — processing, moderation, then
/// published or rejected. [polling] is false once the status is final or
/// polling timed out (the creator can check their profile later).
final class UploadTracking extends ReelUploadState {
  const UploadTracking(this.reel, {required this.polling});
  final Reel reel;
  final bool polling;
  @override
  List<Object?> get props => [reel, polling];
}

String uploadRuleMessage(Failure f) => switch (f.code) {
  ReelUploadRule.unreadableDuration =>
    "We couldn't read this video's length. Try an MP4 recorded on your phone.",
  ReelUploadRule.tooShort => 'Reels must be at least 15 seconds long.',
  ReelUploadRule.tooLong => 'Reels can be up to 60 seconds long.',
  ReelUploadRule.tooLarge => 'This video file is too large to upload.',
  _ => reelsFailureMessage(f),
};

class ReelUploadCubit extends Cubit<ReelUploadState> {
  ReelUploadCubit(
    this._config,
    this._upload,
    this._getReel, {
    ReelVideoPicker? picker,
    CompleteReelUpload? confirmUpload,
    this.pollInterval = const Duration(seconds: 4),
    this.maxPolls = 45,
  }) : _picker = picker,
       _confirmUpload = confirmUpload,
       super(const UploadLoading());

  final GetReelsConfig _config;
  final UploadReel _upload;
  final GetReel _getReel;
  final ReelVideoPicker? _picker;
  final CompleteReelUpload? _confirmUpload;
  final Duration pollInterval;
  final int maxPolls;
  IdempotencyKey _key = IdempotencyKey.generate();
  Timer? _timer;
  int _polls = 0;

  bool get pickerAvailable => _picker != null;

  Future<void> load() async {
    emit(const UploadLoading());
    final cfg = await _config(const NoInput());
    if (isClosed) return;
    switch (cfg) {
      case Err(:final failure):
        emit(UploadUnavailable(reelsFailureMessage(failure)));
      case Success(:final value) when !value.enabled:
        emit(const UploadUnavailable('Reels is not available right now.'));
      case Success(:final value) when !value.uploadsAvailable:
        emit(
          const UploadUnavailable(
            "Video uploads aren't set up on this server yet.",
          ),
        );
      case Success() when _picker == null:
        emit(
          const UploadUnavailable(
            "Recording and choosing videos isn't available in this build.",
          ),
        );
      case Success(:final value):
        emit(UploadPick(value));
    }
  }

  Future<void> pick(ReelVideoSource source) async {
    final s = state;
    final picker = _picker;
    if (s is! UploadPick || picker == null) return;
    final video = await picker.pick(source);
    if (isClosed || video == null) return;
    switch (validatePickedVideo(video, s.config)) {
      case Err(:final failure):
        emit(UploadPick(s.config, error: uploadRuleMessage(failure)));
      case Success(:final value):
        _key = IdempotencyKey.generate();
        emit(UploadPreview(s.config, video, value));
    }
  }

  void discard() {
    final s = state;
    if (s is UploadPreview) emit(UploadPick(s.config));
  }

  Future<void> submit(String caption) async {
    final s = state;
    if (s is! UploadPreview) return;
    final text = caption.trim();
    if (text.runes.length > s.config.maxCaptionLength) {
      emit(
        UploadPreview(
          s.config,
          s.video,
          s.durationMs,
          error:
              'Captions can be up to ${s.config.maxCaptionLength} characters.',
        ),
      );
      return;
    }
    emit(const UploadSending(0));
    final res = await _upload((
      video: s.video,
      durationMs: s.durationMs,
      caption: text,
      language: null,
      idempotencyKey: _key,
      onProgress: (p) {
        if (!isClosed && state is UploadSending) emit(UploadSending(p));
      },
    ));
    if (isClosed) return;
    switch (res) {
      case Err(:final failure):
        // Same idempotency key on retry: never two reels for one tap.
        emit(
          UploadPreview(
            s.config,
            s.video,
            s.durationMs,
            error: reelsFailureMessage(failure),
          ),
        );
      case Success(:final value):
        _polls = 0;
        emit(UploadTracking(value, polling: true));
        _schedulePoll(value.id);
    }
  }

  void _schedulePoll(String id) {
    _timer?.cancel();
    _timer = Timer(pollInterval, () => _poll(id));
  }

  Future<void> _poll(String id) async {
    if (isClosed) return;
    _polls++;
    final before = state;
    // The server has not confirmed the file yet (the confirm call after the
    // upload failed, e.g. the network dropped): ask it to check again
    // instead of waiting for the server's slower fallback job.
    final confirm = _confirmUpload;
    final res =
        before is UploadTracking &&
            before.reel.status == ReelStatus.awaitingUpload &&
            confirm != null
        ? await confirm(id)
        : await _getReel(id);
    if (isClosed) return;
    final cur = state;
    if (cur is! UploadTracking) return;
    final reel = switch (res) {
      Success(:final value) => value,
      Err() => cur.reel,
    };
    final keepGoing = reel.status.isInFlight && _polls < maxPolls;
    emit(UploadTracking(reel, polling: keepGoing));
    if (keepGoing) _schedulePoll(id);
  }

  void startOver() {
    _timer?.cancel();
    load();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
