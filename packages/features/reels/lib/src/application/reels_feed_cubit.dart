import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/creator_profile.dart';
import '../domain/entities/reel.dart';
import '../domain/usecases/reels_usecases.dart';

sealed class ReelsFeedState extends Equatable {
  const ReelsFeedState(this.tab);
  final FeedTab tab;
  @override
  List<Object?> get props => [tab];
}

final class ReelsFeedLoading extends ReelsFeedState {
  const ReelsFeedLoading(super.tab);
}

final class ReelsFeedFailed extends ReelsFeedState {
  const ReelsFeedFailed(super.tab, this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [tab, failure];
}

final class ReelsFeedLoaded extends ReelsFeedState {
  const ReelsFeedLoaded(
    super.tab, {
    required this.items,
    required this.nextCursor,
    this.index = 0,
    this.loadingMore = false,
    this.muted = true,
    this.paused = false,
    this.uploadsAvailable = false,
    this.notice,
    this.noticeSeq = 0,
  });

  final List<Reel> items;
  final String? nextCursor;
  final int index;
  final bool loadingMore;
  final bool muted;
  final bool paused;
  final bool uploadsAvailable;

  /// One-off message for a snackbar (e.g. "Link copied"); [noticeSeq]
  /// changes each time so the same text can show twice.
  final String? notice;
  final int noticeSeq;

  bool get hasMore => nextCursor != null;

  ReelsFeedLoaded copyWith({
    List<Reel>? items,
    String? nextCursor,
    bool clearCursor = false,
    int? index,
    bool? loadingMore,
    bool? muted,
    bool? paused,
    String? notice,
  }) => ReelsFeedLoaded(
    tab,
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    index: index ?? this.index,
    loadingMore: loadingMore ?? this.loadingMore,
    muted: muted ?? this.muted,
    paused: paused ?? this.paused,
    uploadsAvailable: uploadsAvailable,
    notice: notice,
    noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
  );

  @override
  List<Object?> get props => [
    tab,
    items,
    nextCursor,
    index,
    loadingMore,
    muted,
    paused,
    uploadsAvailable,
    notice,
    noticeSeq,
  ];
}

/// Plain-language copy for Reels failures.
String reelsFailureMessage(Failure f) => switch (f.code) {
  'reels_disabled' => 'Reels is not available right now.',
  'not_age_eligible' => 'Reels is for adults. Complete the 18+ check first.',
  'account_restricted' =>
    "Your account can't post or interact on Reels right now.",
  'video_provider_not_configured' =>
    "Video uploads aren't set up on this server yet.",
  'video_provider_unavailable' =>
    "We couldn't start the upload. Please try again.",
  'reel_upload_limit' => 'You can post up to 10 reels a day.',
  'appeal_not_allowed' => 'Only rejected or removed reels can be appealed.',
  'already_appealed' => 'You already appealed this reel.',
  'self_follow' => "You can't follow yourself.",
  'self_report' => "You can't report your own reel.",
  _ => failureMessage(f),
};

/// Vertical Reels feed: pages, like/follow (optimistic), share, report,
/// mute, and analytics events (buffered, sent in batches).
class ReelsFeedCubit extends Cubit<ReelsFeedState> {
  ReelsFeedCubit(
    this._feed,
    this._like,
    this._follow,
    this._share,
    this._report,
    this._track,
    this._config,
    this._getReel, {
    String? sessionId,
  }) : _session = sessionId ?? IdempotencyKey.generate().value.substring(0, 32),
       super(const ReelsFeedLoading(FeedTab.forYou));

  final GetReelsFeed _feed;
  final SetReelLike _like;
  final SetCreatorFollow _follow;
  final ShareReel _share;
  final ReportReel _report;
  final TrackReelEvents _track;
  final GetReelsConfig _config;
  final GetReel _getReel;
  final String _session;
  final List<ReelEvent> _buffer = [];
  final Set<String> _impressed = {};
  bool _uploadsAvailable = false;

  static const flushAt = 10;

  Future<void> load([FeedTab tab = FeedTab.forYou]) async {
    emit(ReelsFeedLoading(tab));
    final cfg = await _config(const NoInput());
    switch (cfg) {
      case Err(:final failure):
        emit(ReelsFeedFailed(tab, failure));
        return;
      case Success(:final value) when !value.enabled:
        emit(ReelsFeedFailed(tab, const ServerFailure(code: 'reels_disabled')));
        return;
      case Success(:final value):
        _uploadsAvailable = value.uploadsAvailable;
    }
    final page = await _feed((tab: tab, cursor: null));
    if (isClosed) return;
    switch (page) {
      case Err(:final failure):
        emit(ReelsFeedFailed(tab, failure));
      case Success(:final value):
        emit(
          ReelsFeedLoaded(
            tab,
            items: value.items,
            nextCursor: value.nextCursor,
            uploadsAvailable: _uploadsAvailable,
          ),
        );
        if (value.items.isNotEmpty) _impression(value.items.first);
    }
  }

  /// Single-reel mode (opened from a creator grid or a shared link).
  Future<void> openSingle(String reelId) async {
    emit(const ReelsFeedLoading(FeedTab.forYou));
    final res = await _getReel(reelId);
    if (isClosed) return;
    switch (res) {
      case Err(:final failure):
        emit(ReelsFeedFailed(FeedTab.forYou, failure));
      case Success(:final value):
        emit(ReelsFeedLoaded(FeedTab.forYou, items: [value], nextCursor: null));
        _impression(value);
    }
  }

  Future<void> setTab(FeedTab tab) async {
    if (state.tab == tab && state is ReelsFeedLoaded) return;
    await flush();
    await load(tab);
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! ReelsFeedLoaded || !s.hasMore || s.loadingMore) return;
    emit(s.copyWith(loadingMore: true));
    final page = await _feed((tab: s.tab, cursor: s.nextCursor));
    if (isClosed) return;
    final cur = state;
    if (cur is! ReelsFeedLoaded || cur.tab != s.tab) return;
    switch (page) {
      case Err():
        emit(
          cur.copyWith(loadingMore: false, notice: "Couldn't load more reels."),
        );
      case Success(:final value):
        final known = cur.items.map((r) => r.id).toSet();
        emit(
          cur.copyWith(
            items: [
              ...cur.items,
              ...value.items.where((r) => !known.contains(r.id)),
            ],
            nextCursor: value.nextCursor,
            clearCursor: value.nextCursor == null,
            loadingMore: false,
          ),
        );
    }
  }

  void onPageChanged(int index) {
    final s = state;
    if (s is! ReelsFeedLoaded || index < 0 || index >= s.items.length) return;
    emit(s.copyWith(index: index, paused: false));
    _impression(s.items[index]);
    if (index >= s.items.length - 3) loadMore();
  }

  void toggleMute() {
    final s = state;
    if (s is ReelsFeedLoaded) emit(s.copyWith(muted: !s.muted));
  }

  void togglePause() {
    final s = state;
    if (s is ReelsFeedLoaded) emit(s.copyWith(paused: !s.paused));
  }

  Reel? _find(String id) {
    final s = state;
    if (s is! ReelsFeedLoaded) return null;
    for (final r in s.items) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _replace(bool Function(Reel) where, Reel Function(Reel) change) {
    final s = state;
    if (s is! ReelsFeedLoaded) return;
    emit(
      s.copyWith(items: [for (final r in s.items) where(r) ? change(r) : r]),
    );
  }

  Future<void> toggleLike(String id) async {
    final r = _find(id);
    if (r == null) return;
    final like = !r.likedByMe;
    _replace(
      (x) => x.id == id,
      (x) =>
          x.copyWith(likedByMe: like, likeCount: x.likeCount + (like ? 1 : -1)),
    );
    final res = await _like((id: id, like: like));
    if (isClosed) return;
    switch (res) {
      case Success(:final value):
        _replace(
          (x) => x.id == id,
          (x) => x.copyWith(likedByMe: value.liked, likeCount: value.likeCount),
        );
      case Err(:final failure):
        _replace((x) => x.id == id, (_) => r);
        _notice(reelsFailureMessage(failure));
    }
  }

  Future<void> toggleFollow(String creatorId) async {
    final r = _findByCreator(creatorId);
    if (r == null) return;
    final follow = !r.creator.followedByMe;
    _setFollow(creatorId, follow);
    final res = await _follow((creatorId: creatorId, follow: follow));
    if (isClosed) return;
    switch (res) {
      case Success(:final value):
        _setFollow(creatorId, value);
      case Err(:final failure):
        _setFollow(creatorId, !follow);
        _notice(reelsFailureMessage(failure));
    }
  }

  Reel? _findByCreator(String creatorId) {
    final s = state;
    if (s is! ReelsFeedLoaded) return null;
    for (final r in s.items) {
      if (r.creator.userId == creatorId) return r;
    }
    return null;
  }

  void _setFollow(String creatorId, bool follow) => _replace(
    (x) => x.creator.userId == creatorId,
    (x) => x.copyWith(creator: x.creator.copyWith(followedByMe: follow)),
  );

  /// Returns the share text for the page to copy, or null on failure.
  Future<String?> share(String id) async {
    final res = await _share(id);
    if (isClosed) return null;
    switch (res) {
      case Success(:final value):
        _replace(
          (x) => x.id == id,
          (x) => x.copyWith(shareCount: x.shareCount + 1),
        );
        return value;
      case Err(:final failure):
        _notice(reelsFailureMessage(failure));
        return null;
    }
  }

  void confirmCopied() => _notice('Link copied. Paste it anywhere to share.');

  /// Reports and removes the reel from this feed.
  Future<bool> report(
    String id,
    ReelReportCategory category, {
    String? details,
  }) async {
    final res = await _report((id: id, category: category, details: details));
    if (isClosed) return false;
    switch (res) {
      case Success():
        final s = state;
        if (s is ReelsFeedLoaded) {
          final items = s.items.where((r) => r.id != id).toList();
          emit(
            s.copyWith(
              items: items,
              index: s.index.clamp(0, items.isEmpty ? 0 : items.length - 1),
              notice: 'Thanks. Our team will review this reel.',
            ),
          );
        }
        return true;
      case Err(:final failure):
        _notice(reelsFailureMessage(failure));
        return false;
    }
  }

  /// The viewer blocked [creatorId] in the safety flow (which only pops
  /// with `true` after the server confirmed the block): their reels leave
  /// this feed now; the server already excludes them from later pages.
  void creatorBlocked(String creatorId, String name) {
    final s = state;
    if (s is! ReelsFeedLoaded) return;
    final items = s.items.where((r) => r.creator.userId != creatorId).toList();
    emit(
      s.copyWith(
        items: items,
        index: s.index.clamp(0, items.isEmpty ? 0 : items.length - 1),
        notice: "$name is blocked. You won't see their reels.",
      ),
    );
  }

  void _notice(String text) {
    final s = state;
    if (s is ReelsFeedLoaded) emit(s.copyWith(notice: text));
  }

  // ---------------------------------------------------------------- analytics

  void _impression(Reel r) {
    if (_impressed.add(r.id)) {
      _event(ReelEvent(name: ReelEventName.impression, reelId: r.id));
    }
  }

  /// Reported by a real player only (never when playback is unavailable).
  void playStarted(String reelId) =>
      _event(ReelEvent(name: ReelEventName.playStarted, reelId: reelId));

  void playCompleted(String reelId, int watchedMs) {
    _event(
      ReelEvent(
        name: ReelEventName.playCompleted,
        reelId: reelId,
        valueMs: watchedMs,
      ),
    );
  }

  void watched(String reelId, int watchedMs) => _event(
    ReelEvent(
      name: ReelEventName.watchDuration,
      reelId: reelId,
      valueMs: watchedMs,
    ),
  );

  void creatorOpened(Reel r) => _event(
    ReelEvent(
      name: ReelEventName.creatorProfileOpened,
      reelId: r.id,
      creatorId: r.creator.userId,
    ),
  );

  /// Logged before navigating to the call screen; the server attributes a
  /// call to Reels only if it starts within 30 minutes of this click.
  void callCtaClicked(Reel r) {
    _event(
      ReelEvent(
        name: ReelEventName.hostCallCtaClicked,
        reelId: r.id,
        creatorId: r.creator.userId,
      ),
    );
    flush();
  }

  void _event(ReelEvent e) {
    _buffer.add(
      ReelEvent(
        name: e.name,
        reelId: e.reelId,
        creatorId: e.creatorId,
        valueMs: e.valueMs,
        sessionId: _session,
      ),
    );
    if (_buffer.length >= flushAt) flush();
  }

  /// Sends buffered events. Analytics never blocks or fails the UI.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final batch = List<ReelEvent>.of(_buffer);
    _buffer.clear();
    await _track(batch);
  }

  @override
  Future<void> close() async {
    await flush();
    return super.close();
  }
}
