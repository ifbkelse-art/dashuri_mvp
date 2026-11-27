import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/reels_feed_cubit.dart';
import '../../domain/entities/reel.dart';
import '../widgets/reel_player.dart';
import '../widgets/reel_view.dart';

/// Reels tab (For You / Following) and the single-reel viewer.
class ReelsFeedPage extends StatefulWidget {
  const ReelsFeedPage({super.key, this.player, this.single = false});

  final ReelPlayerFactory? player;

  /// Single-reel mode: no tabs, back button, no paging.
  final bool single;

  @override
  State<ReelsFeedPage> createState() => _ReelsFeedPageState();
}

class _ReelsFeedPageState extends State<ReelsFeedPage> {
  final _pages = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion: reels start paused; a tap plays them.
    context.read<ReelsFeedCubit>().setAutoplay(
      !MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ReelActions _actions(BuildContext context, Reel r) {
    final cubit = context.read<ReelsFeedCubit>();
    return ReelActions(
      onLike: () => cubit.toggleLike(r.id),
      onFollow: () => cubit.toggleFollow(r.creator.userId),
      onShare: () async {
        final text = await cubit.share(r.id);
        if (text == null) return;
        await Clipboard.setData(ClipboardData(text: text));
        cubit.confirmCopied();
      },
      onReport: (c) => cubit.report(r.id, c),
      onBlocked: () =>
          cubit.creatorBlocked(r.creator.userId, r.creator.displayName),
      onOpenCreator: () {
        cubit.creatorOpened(r);
        context.push(
          RoutePaths.withParams(RoutePaths.reelCreator, {
            'userId': r.isMine ? 'me' : r.creator.userId,
          }),
        );
      },
      onCallCta: () {
        cubit.callCtaClicked(r);
        context.push(hostCtaLocation(r.creator));
      },
      onToggleMute: cubit.toggleMute,
      onTogglePause: cubit.togglePause,
      callbacks: ReelPlayerCallbacks(
        onStarted: () => cubit.playStarted(r.id),
        onCompleted: (ms) => cubit.playCompleted(r.id, ms),
        onStopped: (ms) => cubit.watched(r.id, ms),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ReelsFeedCubit, ReelsFeedState>(
    listenWhen: (a, b) =>
        b is ReelsFeedLoaded &&
        b.notice != null &&
        (a is! ReelsFeedLoaded || a.noticeSeq != b.noticeSeq),
    listener: (context, s) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text((s as ReelsFeedLoaded).notice!))),
    builder: (context, s) => Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.single ? null : _Tabs(tab: s.tab),
        centerTitle: true,
        // Customer mode only watches reels. Posting lives in host mode
        // (host Profile tab → My reels), and the backend enforces it.
      ),
      body: switch (s) {
        ReelsFeedLoading() => const LoadingView(),
        ReelsFeedFailed(:final failure, :final tab) => _OnDark(
          child: ErrorStateView(
            title: failure.code == 'reels_disabled'
                ? 'Reels is off'
                : "Couldn't load reels",
            message: reelsFailureMessage(failure),
            onRetry: failure.code == 'reels_disabled'
                ? null
                : () => context.read<ReelsFeedCubit>().load(tab),
          ),
        ),
        ReelsFeedLoaded(items: final items, :final tab) when items.isEmpty =>
          _OnDark(
            child: EmptyStateView(
              icon: tab == FeedTab.following
                  ? Icons.people_outline
                  : Icons.movie_outlined,
              title: tab == FeedTab.following
                  ? 'No reels from people you follow'
                  : 'No reels yet',
              message: tab == FeedTab.following
                  ? 'Follow creators from the For you tab to see their reels here.'
                  : 'Be the first to post. New reels appear after a quick safety review.',
              actionLabel: tab == FeedTab.following
                  ? 'Explore For you'
                  : 'Refresh',
              onAction: () => tab == FeedTab.following
                  ? context.read<ReelsFeedCubit>().setTab(FeedTab.forYou)
                  : context.read<ReelsFeedCubit>().load(tab),
            ),
          ),
        final ReelsFeedLoaded loaded => RefreshIndicator(
          onRefresh: () => context.read<ReelsFeedCubit>().load(loaded.tab),
          child: PageView.builder(
            key: PageStorageKey('reels-${loaded.tab.wire}'),
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: loaded.items.length + (loaded.hasMore ? 1 : 0),
            onPageChanged: context.read<ReelsFeedCubit>().onPageChanged,
            itemBuilder: (context, i) {
              if (i >= loaded.items.length) return const LoadingView();
              final r = loaded.items[i];
              return ReelView(
                key: ValueKey(r.id),
                reel: r,
                player: widget.player,
                active: i == loaded.index,
                preload: i == loaded.index + 1,
                muted: loaded.muted,
                paused: loaded.paused,
                actions: _actions(context, r),
              );
            },
          ),
        ),
      },
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab});
  final FeedTab tab;

  @override
  Widget build(BuildContext context) => SegmentedButton<FeedTab>(
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      // A dark backing keeps the unselected label readable over bright
      // video frames (it was white text on whatever the frame was).
      backgroundColor: DashuriColors.mediaScrim,
      foregroundColor: DashuriColors.onMedia,
      selectedForegroundColor: DashuriTokens.neutral900,
      selectedBackgroundColor: Colors.white,
      side: const BorderSide(color: Colors.white54),
      visualDensity: VisualDensity.compact,
    ),
    segments: const [
      ButtonSegment(value: FeedTab.forYou, label: Text('For you')),
      ButtonSegment(value: FeedTab.following, label: Text('Following')),
    ],
    selected: {tab},
    onSelectionChanged: (v) => context.read<ReelsFeedCubit>().setTab(v.first),
  );
}

/// The feed is a dark, full-screen page (the nav bar and status bar are
/// light on it), so its empty and error views use the dark theme on black.
class _OnDark extends StatelessWidget {
  const _OnDark({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = DashuriTheme.dark();
    return Theme(
      data: dark,
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(child: ResponsiveCenter(child: child)),
      ),
    );
  }
}
