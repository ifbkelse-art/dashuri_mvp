import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/creator_profile.dart';
import '../domain/entities/reel.dart';
import '../domain/usecases/reels_usecases.dart';
import 'reels_feed_cubit.dart' show reelsFailureMessage;

sealed class CreatorProfileState extends Equatable {
  const CreatorProfileState();
  @override
  List<Object?> get props => [];
}

final class CreatorProfileLoading extends CreatorProfileState {
  const CreatorProfileLoading();
}

final class CreatorProfileFailed extends CreatorProfileState {
  const CreatorProfileFailed(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

final class CreatorProfileLoaded extends CreatorProfileState {
  const CreatorProfileLoaded({
    required this.profile,
    required this.reels,
    required this.nextCursor,
    this.loadingMore = false,
    this.busy = false,
    this.notice,
    this.noticeSeq = 0,
  });

  final CreatorProfile profile;
  final List<Reel> reels;
  final String? nextCursor;
  final bool loadingMore;
  final bool busy;
  final String? notice;
  final int noticeSeq;

  CreatorProfileLoaded copyWith({
    CreatorProfile? profile,
    List<Reel>? reels,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    bool? busy,
    String? notice,
  }) => CreatorProfileLoaded(
    profile: profile ?? this.profile,
    reels: reels ?? this.reels,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loadingMore: loadingMore ?? this.loadingMore,
    busy: busy ?? this.busy,
    notice: notice,
    noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
  );

  @override
  List<Object?> get props => [
    profile,
    reels,
    nextCursor,
    loadingMore,
    busy,
    notice,
    noticeSeq,
  ];
}

/// Creator profile: header, follow, published grid; on one's own profile
/// every reel with its processing/moderation status, delete and appeal.
class CreatorProfileCubit extends Cubit<CreatorProfileState> {
  CreatorProfileCubit(
    this._profile,
    this._reels,
    this._follow,
    this._delete,
    this._appeal,
  ) : super(const CreatorProfileLoading());

  final GetCreatorProfile _profile;
  final GetCreatorReels _reels;
  final SetCreatorFollow _follow;
  final DeleteReel _delete;
  final AppealReel _appeal;
  String? _userId;

  Future<void> load(String userId) async {
    _userId = userId;
    emit(const CreatorProfileLoading());
    final p = await _profile(userId);
    if (isClosed) return;
    switch (p) {
      case Err(:final failure):
        emit(CreatorProfileFailed(failure));
        return;
      case Success(value: final profile):
        final page = await _reels((userId: userId, cursor: null));
        if (isClosed) return;
        switch (page) {
          case Err(:final failure):
            emit(CreatorProfileFailed(failure));
          case Success(:final value):
            emit(
              CreatorProfileLoaded(
                profile: profile,
                reels: value.items,
                nextCursor: value.nextCursor,
              ),
            );
        }
    }
  }

  Future<void> refresh() async {
    final id = _userId;
    if (id != null) await load(id);
  }

  Future<void> loadMore() async {
    final s = state;
    final id = _userId;
    if (s is! CreatorProfileLoaded ||
        s.nextCursor == null ||
        s.loadingMore ||
        id == null) {
      return;
    }
    emit(s.copyWith(loadingMore: true));
    final page = await _reels((userId: id, cursor: s.nextCursor));
    if (isClosed) return;
    final cur = state;
    if (cur is! CreatorProfileLoaded) return;
    switch (page) {
      case Err():
        emit(
          cur.copyWith(loadingMore: false, notice: "Couldn't load more reels."),
        );
      case Success(:final value):
        final known = cur.reels.map((r) => r.id).toSet();
        emit(
          cur.copyWith(
            reels: [
              ...cur.reels,
              ...value.items.where((r) => !known.contains(r.id)),
            ],
            nextCursor: value.nextCursor,
            clearCursor: value.nextCursor == null,
            loadingMore: false,
          ),
        );
    }
  }

  Future<void> toggleFollow() async {
    final s = state;
    if (s is! CreatorProfileLoaded || s.profile.isSelf || s.busy) return;
    final follow = !s.profile.creator.followedByMe;
    emit(
      s.copyWith(
        busy: true,
        profile: s.profile.copyWith(
          followedByMe: follow,
          followerCount: s.profile.followerCount + (follow ? 1 : -1),
        ),
      ),
    );
    final res = await _follow((
      creatorId: s.profile.creator.userId,
      follow: follow,
    ));
    if (isClosed) return;
    final cur = state as CreatorProfileLoaded;
    switch (res) {
      case Success():
        emit(cur.copyWith(busy: false));
      case Err(:final failure):
        emit(s.copyWith(busy: false, notice: reelsFailureMessage(failure)));
    }
  }

  Future<bool> deleteReel(String id) async {
    final s = state;
    if (s is! CreatorProfileLoaded || !s.profile.isSelf) return false;
    emit(s.copyWith(busy: true));
    final res = await _delete(id);
    if (isClosed) return false;
    final cur = state as CreatorProfileLoaded;
    switch (res) {
      case Success():
        emit(
          cur.copyWith(
            busy: false,
            reels: cur.reels.where((r) => r.id != id).toList(),
            notice: 'Reel deleted.',
          ),
        );
        return true;
      case Err(:final failure):
        emit(cur.copyWith(busy: false, notice: reelsFailureMessage(failure)));
        return false;
    }
  }

  Future<bool> appeal(String id, String statement) async {
    final s = state;
    final text = statement.trim();
    if (s is! CreatorProfileLoaded || text.isEmpty) return false;
    emit(s.copyWith(busy: true));
    final res = await _appeal((id: id, statement: text));
    if (isClosed) return false;
    final cur = state as CreatorProfileLoaded;
    switch (res) {
      case Success():
        emit(
          cur.copyWith(
            busy: false,
            notice: 'Appeal sent. A moderator will review it.',
          ),
        );
        return true;
      case Err(:final failure):
        emit(cur.copyWith(busy: false, notice: reelsFailureMessage(failure)));
        return false;
    }
  }
}
