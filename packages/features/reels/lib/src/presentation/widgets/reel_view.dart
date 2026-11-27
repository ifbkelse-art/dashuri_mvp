import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/creator_profile.dart';
import '../../domain/entities/reel.dart';
import 'reel_player.dart';

/// Everything a reel page can do; supplied by the page from its cubit.
final class ReelActions {
  const ReelActions({
    required this.onLike,
    required this.onFollow,
    required this.onShare,
    required this.onReport,
    required this.onOpenCreator,
    required this.onCallCta,
    required this.onToggleMute,
    required this.onTogglePause,
    required this.callbacks,
    this.onBlocked,
  });

  final VoidCallback onLike;
  final VoidCallback onFollow;
  final VoidCallback onShare;
  final void Function(ReelReportCategory category) onReport;
  final VoidCallback onOpenCreator;
  final VoidCallback onCallCta;
  final VoidCallback onToggleMute;
  final VoidCallback onTogglePause;
  final ReelPlayerCallbacks callbacks;

  /// The block flow confirmed a block of this reel's creator.
  final VoidCallback? onBlocked;
}

/// Shadows that keep white overlay text readable over any video frame,
/// including bright ones above the bottom gradient.
const _overlayShadows = [
  Shadow(blurRadius: 4, color: Color(0xCC000000)),
  Shadow(blurRadius: 10, color: Color(0x80000000)),
];

String _availabilityLabel(ReelHost h) => switch (h.availability) {
  'online' => 'Online',
  'busy' => 'In a call',
  _ => 'Offline',
};

StatusTone _availabilityTone(ReelHost h) => switch (h.availability) {
  'online' => StatusTone.online,
  'busy' => StatusTone.busy,
  _ => StatusTone.offline,
};

/// One full-screen reel: video (or poster), creator, caption, actions and,
/// for approved hosts, availability and the call CTA. Responsive: the 9:16
/// video is centred with actions beside it on wide windows.
class ReelView extends StatelessWidget {
  const ReelView({
    required this.reel,
    required this.actions,
    required this.active,
    required this.muted,
    required this.paused,
    super.key,
    this.player,
    this.preload = false,
  });

  final Reel reel;
  final ReelActions actions;
  final bool active;
  final bool muted;
  final bool paused;
  final ReelPlayerFactory? player;

  /// The next reel after the active one (the player may preload it).
  final bool preload;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth >= 720;
      final videoW = (c.maxHeight * 9 / 16).clamp(
        0.0,
        wide ? c.maxWidth - 220 : c.maxWidth,
      );
      final video = _Video(
        reel: reel,
        player: player,
        active: active,
        preload: preload,
        muted: muted,
        paused: paused,
        actions: actions,
        showActionsInside: !wide,
      );
      if (!wide) return video;
      return ColoredBox(
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: videoW, child: video),
            const SizedBox(width: DashuriTokens.space4),
            SizedBox(
              width: 180,
              child: Padding(
                // Never under the (transparent, tap-absorbing) app bar.
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DashuriTokens.space8),
                  // Three buttons: shrink rather than scroll if too tall.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: _ActionColumn(reel: reel, actions: actions),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Video extends StatelessWidget {
  const _Video({
    required this.reel,
    required this.player,
    required this.active,
    required this.preload,
    required this.muted,
    required this.paused,
    required this.actions,
    required this.showActionsInside,
  });

  final Reel reel;
  final ReelPlayerFactory? player;
  final bool active, preload, muted, paused, showActionsInside;
  final ReelActions actions;

  @override
  Widget build(BuildContext context) {
    final pb = reel.playback;
    final canPlay = player != null && pb != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (canPlay)
          GestureDetector(
            onTap: actions.onTogglePause,
            child: player!.build(
              playback: pb,
              active: active,
              preload: preload,
              muted: muted,
              paused: paused,
              callbacks: actions.callbacks,
            ),
          )
        else
          ReelPosterView(playback: pb),
        // Readability gradient behind the text.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black87],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        if (canPlay) ...[
          Positioned(
            top: DashuriTokens.space3,
            right: DashuriTokens.space3,
            child: SafeArea(
              child: IconButton.filledTonal(
                tooltip: muted ? 'Unmute' : 'Mute',
                onPressed: actions.onToggleMute,
                icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              ),
            ),
          ),
          if (paused)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                size: 88,
                color: Colors.white70,
              ),
            ),
        ],
        // Bounded below the app bar: on short windows (landscape, large
        // text) the info used to grow past the top edge, hiding the
        // creator, Follow and caption. It now scrolls instead. Clamping
        // physics only takes drags when it really overflows, so swiping
        // to the next reel keeps working everywhere else.
        Positioned(
          left: DashuriTokens.space4,
          right: showActionsInside ? 76 : DashuriTokens.space4,
          bottom: DashuriTokens.space4,
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                reverse: true,
                physics: const ClampingScrollPhysics(),
                child: _Info(reel: reel, actions: actions),
              ),
            ),
          ),
        ),
        if (showActionsInside)
          Positioned(
            right: DashuriTokens.space2,
            bottom: DashuriTokens.space6,
            top: MediaQuery.paddingOf(context).top + kToolbarHeight,
            child: SafeArea(
              top: false,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomRight,
                child: _ActionColumn(reel: reel, actions: actions),
              ),
            ),
          ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.reel, required this.actions});

  final Reel reel;
  final ReelActions actions;

  @override
  Widget build(BuildContext context) {
    final c = reel.creator;
    final host = c.host;
    const white = TextStyle(
      color: DashuriColors.onMedia,
      shadows: _overlayShadows,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DashuriTokens.space2,
          runSpacing: DashuriTokens.space1,
          children: [
            InkWell(
              onTap: actions.onOpenCreator,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(name: c.displayName, url: c.photoUrl, radius: 18),
                  const SizedBox(width: DashuriTokens.space2),
                  // Takes what is left of the row (never a fixed width), so
                  // the chip fits narrow overlays and large text.
                  Flexible(
                    child: Text(
                      c.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: white.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (host?.isVerified ?? false) ...[
                    const SizedBox(width: DashuriTokens.space1),
                    const Icon(
                      Icons.verified,
                      size: 16,
                      color: Colors.white,
                      shadows: _overlayShadows,
                      semanticLabel: 'Verified host',
                    ),
                  ],
                ],
              ),
            ),
            if (!reel.isMine)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: c.followedByMe
                      ? DashuriColors.mediaScrim
                      : Colors.transparent,
                  side: const BorderSide(color: Colors.white70),
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(64, 36),
                ),
                onPressed: actions.onFollow,
                child: Text(c.followedByMe ? 'Following' : 'Follow'),
              ),
          ],
        ),
        if (reel.caption.isNotEmpty) ...[
          const SizedBox(height: DashuriTokens.space2),
          _Caption(text: reel.caption, style: white),
        ],
        if (host != null && !reel.isMine) ...[
          const SizedBox(height: DashuriTokens.space3),
          Wrap(
            spacing: DashuriTokens.space2,
            runSpacing: DashuriTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusTag(
                label: _availabilityLabel(host),
                tone: _availabilityTone(host),
                dot: true,
              ),
              // Only an online host gets a call button. The creator's name
              // above already opens their profile, so offline hosts need no
              // separate "View host profile" button.
              if (host.isOnline)
                FilledButton.icon(
                  onPressed: actions.onCallCta,
                  icon: const Icon(Icons.videocam),
                  label: Text(
                    'Video call · ${DashuriFormat.count(host.ratePerMinute)} Diamonds/min',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Caption: three lines, then "more" expands it in place (long captions
/// never push the actions off screen: the expanded text scrolls).
class _Caption extends StatefulWidget {
  const _Caption({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 3,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: c.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      final text = Text(
        widget.text,
        maxLines: _open ? null : 3,
        overflow: _open ? null : TextOverflow.ellipsis,
        style: widget.style,
      );
      if (!long) return text;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_open)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .3,
              ),
              child: SingleChildScrollView(child: text),
            )
          else
            text,
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _open ? 'less' : 'more',
                style: widget.style.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({required this.reel, required this.actions});

  final Reel reel;
  final ReelActions actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Action(
        icon: reel.likedByMe ? Icons.favorite : Icons.favorite_border,
        color: reel.likedByMe ? DashuriTokens.burgundy300 : Colors.white,
        label: DashuriFormat.count(reel.likeCount),
        tooltip: reel.likedByMe ? 'Unlike' : 'Like',
        onTap: actions.onLike,
        // A short pop when the state flips (server-confirmed or rolled back).
        animateKey: reel.likedByMe,
      ),
      _Action(
        icon: Icons.ios_share,
        label: 'Share',
        tooltip: 'Copy link to share',
        onTap: actions.onShare,
      ),
      if (!reel.isMine)
        _Action(
          icon: Icons.more_horiz,
          label: 'More',
          tooltip: 'Report or block',
          onTap: () => showReelMoreSheet(context, reel, actions),
        ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white,
    this.animateKey,
  });

  final IconData icon;
  final String label, tooltip;
  final VoidCallback onTap;
  final Color color;
  final Object? animateKey;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DashuriTokens.space3),
    child: Column(
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          iconSize: 30,
          icon: TweenAnimationBuilder<double>(
            key: ValueKey(animateKey),
            tween: Tween(begin: animateKey == null ? 1 : 0.6, end: 1),
            duration: DashuriTokens.motionMedium,
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(icon, color: color, shadows: _overlayShadows),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: _overlayShadows,
          ),
        ),
      ],
    ),
  );
}

/// Report (Reels categories) or block (existing safety flow, S06/V13).
Future<void> showReelMoreSheet(
  BuildContext context,
  Reel reel,
  ReelActions actions,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  // Keep the sheet below the status bar so its handle and close button stay
  // reachable when the list is taller than the screen.
  useSafeArea: true,
  builder: (sheet) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: DashuriTokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Report this reel',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheet),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DashuriTokens.space4,
              DashuriTokens.space1,
              DashuriTokens.space4,
              DashuriTokens.space2,
            ),
            child: Text(
              "Reports are anonymous. We'll hide it from you right away.",
            ),
          ),
          for (final c in ReelReportCategory.values)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(c.label),
              onTap: () {
                Navigator.pop(sheet);
                actions.onReport(c);
              },
            ),
          const Divider(),
          ListTile(
            iconColor: Theme.of(sheet).colorScheme.error,
            textColor: Theme.of(sheet).colorScheme.error,
            leading: const Icon(Icons.block),
            title: Text('Block ${reel.creator.displayName}'),
            subtitle: const Text(
              "You won't see each other's reels or profiles.",
            ),
            onTap: () async {
              Navigator.pop(sheet);
              final blocked = await context.push<bool>(
                Uri(
                  path: RoutePaths.report,
                  queryParameters: {
                    'userId': reel.creator.userId,
                    'name': reel.creator.displayName,
                    'mode': 'block',
                  },
                ).toString(),
              );
              if (blocked ?? false) actions.onBlocked?.call();
            },
          ),
        ],
      ),
    ),
  ),
);

/// Where the host CTA goes: the existing pre-call screen (V01, balance and
/// rate checks) when online, otherwise the host profile (C07–C09).
String hostCtaLocation(ReelCreator creator) {
  final host = creator.host;
  final params = {'userId': creator.userId};
  return host != null && host.isOnline
      ? RoutePaths.withParams(RoutePaths.preCall, params)
      : RoutePaths.withParams(RoutePaths.hostProfile, params);
}
