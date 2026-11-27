import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/creator_profile_cubit.dart';
import '../../application/reels_feed_cubit.dart' show reelsFailureMessage;
import '../../domain/entities/reel.dart';
import '../widgets/reel_view.dart' show hostCtaLocation;

String reelStatusLabel(ReelStatus s) => switch (s) {
  ReelStatus.awaitingUpload => 'Uploading',
  ReelStatus.processing => 'Processing',
  ReelStatus.pendingModeration || ReelStatus.inReview => 'In safety review',
  ReelStatus.published => 'Published',
  ReelStatus.rejected => 'Not approved',
  ReelStatus.removed => 'Removed',
  ReelStatus.failed => 'Upload failed',
  ReelStatus.deleted => 'Deleted',
};

StatusTone reelStatusTone(ReelStatus s) => switch (s) {
  ReelStatus.published => StatusTone.success,
  ReelStatus.rejected ||
  ReelStatus.removed ||
  ReelStatus.failed => StatusTone.error,
  _ => StatusTone.warning,
};

/// Plain-language reasons for rejection codes (moderation and processing).
String rejectionMessage(String? code) => switch (code) {
  'sexual_content' =>
    'It appears to contain nudity or sexual content, which Reels does not allow.',
  'graphic_or_offensive' =>
    'It appears to contain graphic or offensive content.',
  'duration_out_of_range' => 'Reels must be 15 to 60 seconds long.',
  // Processing (file) problems: never a rules violation.
  'file_too_large' => 'The video file is too large. Reels can be up to 150 MB.',
  'resolution_too_low' =>
    'The video resolution is too low. Record at 480p or higher.',
  'unsupported_format' || 'no_video_stream' || 'invalid_media' =>
    "This file isn't a video we can play. Record or choose an MP4 or MOV video.",
  'upload_missing' =>
    "The video didn't finish uploading. Try uploading it again.",
  'copyright' => 'It appears to use music or video you do not have rights to.',
  'privacy' => "It shares someone's private information.",
  'minor_safety' => 'It may show someone under 18.',
  'processing_failed' ||
  'upload_failed' ||
  'upload_expired' ||
  'upload_errored' ||
  'upload_cancelled' ||
  'upload_timed_out' =>
    "The video couldn't be processed. Try uploading it again.",
  null => 'It does not meet our community rules.',
  _ => 'It does not meet our community rules.',
};

class CreatorProfilePage extends StatelessWidget {
  const CreatorProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<CreatorProfileCubit, CreatorProfileState>(
        listenWhen: (a, b) =>
            b is CreatorProfileLoaded &&
            b.notice != null &&
            (a is! CreatorProfileLoaded || a.noticeSeq != b.noticeSeq),
        listener: (context, s) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text((s as CreatorProfileLoaded).notice!)),
          ),
        builder: (context, s) => Scaffold(
          appBar: AppBar(
            title: Text(switch (s) {
              CreatorProfileLoaded(:final profile) when profile.isSelf =>
                'My reels',
              CreatorProfileLoaded(:final profile) =>
                profile.creator.displayName,
              _ => 'Creator',
            }),
          ),
          body: switch (s) {
            CreatorProfileLoading() => const LoadingView(),
            CreatorProfileFailed(:final failure) => ErrorStateView(
              title: "Couldn't load this profile",
              message: reelsFailureMessage(failure),
              onRetry: () => context.read<CreatorProfileCubit>().load(userId),
            ),
            final CreatorProfileLoaded l => RefreshIndicator(
              onRefresh: context.read<CreatorProfileCubit>().refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 400) {
                    context.read<CreatorProfileCubit>().loadMore();
                  }
                  return false;
                },
                child: _Loaded(state: l),
              ),
            ),
          },
        ),
      );
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});
  final CreatorProfileLoaded state;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final width = c.maxWidth.clamp(0.0, DashuriTokens.maxContentWidth * 1.4);
      final cols = context.gridColumns(width, minTileWidth: 110, max: 5);
      final gutter = context.pageGutter;
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    DashuriTokens.space4,
                    gutter,
                    DashuriTokens.space4,
                  ),
                  child: _Header(state: state),
                ),
              ),
            ),
          ),
          if (state.reels.isEmpty)
            SliverToBoxAdapter(
              child: EmptyStateView(
                icon: Icons.movie_outlined,
                title: state.profile.isSelf
                    ? 'You have no reels yet'
                    : 'No reels yet',
                message: state.profile.isSelf
                    ? 'Post a 15–60 second video. It appears after a quick safety review.'
                    : null,
                actionLabel: state.profile.isSelf ? 'Post a reel' : null,
                onAction: state.profile.isSelf
                    ? () => context.push(RoutePaths.reelUpload)
                    : null,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ((c.maxWidth - width) / 2) + gutter,
              ).copyWith(bottom: DashuriTokens.space8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 9 / 16,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _Tile(reel: state.reels[i], own: state.profile.isSelf),
                  childCount: state.reels.length,
                ),
              ),
            ),
          if (state.loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DashuriTokens.space4),
                child: LoadingView(),
              ),
            ),
        ],
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final CreatorProfileLoaded state;

  @override
  Widget build(BuildContext context) {
    final p = state.profile;
    final c = p.creator;
    final host = c.host;
    final t = Theme.of(context).textTheme;
    Widget count(int n, String label) => Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          children: [
            Text(DashuriFormat.count(n), style: t.titleMedium),
            Text(label, style: t.bodySmall),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(name: c.displayName, url: c.photoUrl, radius: 36),
            const SizedBox(width: DashuriTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.displayName,
                    style: t.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DashuriTokens.space1),
                  Wrap(
                    spacing: DashuriTokens.space2,
                    runSpacing: DashuriTokens.space1,
                    children: [
                      if (host != null && host.isVerified)
                        const StatusTag(
                          label: 'Verified host',
                          tone: StatusTone.info,
                        ),
                      if (host != null)
                        StatusTag(
                          label: switch (host.availability) {
                            'online' => 'Online',
                            'busy' => 'In a call',
                            _ => 'Offline',
                          },
                          tone: switch (host.availability) {
                            'online' => StatusTone.online,
                            'busy' => StatusTone.busy,
                            _ => StatusTone.offline,
                          },
                          dot: true,
                        ),
                      if (host == null)
                        const StatusTag(
                          label: 'Creator',
                          tone: StatusTone.neutral,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (p.bio != null) ...[
          const SizedBox(height: DashuriTokens.space3),
          Text(p.bio!),
        ],
        const SizedBox(height: DashuriTokens.space4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            count(p.followerCount, 'Followers'),
            count(p.followingCount, 'Following'),
            count(p.reelCount, 'Reels'),
          ],
        ),
        const SizedBox(height: DashuriTokens.space4),
        if (p.isSelf)
          PrimaryButton(
            label: 'Post a reel',
            icon: Icons.add,
            onPressed: () => context.push(RoutePaths.reelUpload),
          )
        else
          Wrap(
            spacing: DashuriTokens.space2,
            runSpacing: DashuriTokens.space2,
            children: [
              if (c.followedByMe)
                OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : context.read<CreatorProfileCubit>().toggleFollow,
                  child: const Text('Following'),
                )
              else
                FilledButton(
                  onPressed: state.busy
                      ? null
                      : context.read<CreatorProfileCubit>().toggleFollow,
                  child: const Text('Follow'),
                ),
              if (host != null)
                // The label wraps (large text, narrow phones) instead of
                // pushing the button past the screen edge.
                FilledButton.tonal(
                  onPressed: () => context.push(hostCtaLocation(c)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          host.isOnline ? Icons.videocam : Icons.person_outline,
                          size: 18,
                        ),
                        const SizedBox(width: DashuriTokens.space2),
                        Flexible(
                          child: Text(
                            host.isOnline
                                ? 'Video call · ${DashuriFormat.count(host.ratePerMinute)} Diamonds/min'
                                : 'View host profile',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.reel, required this.own});
  final Reel reel;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final thumb = reel.playback?.thumbnailUrl;
    return Semantics(
      button: true,
      label: own ? 'Reel, ${reelStatusLabel(reel.status)}' : 'Reel',
      child: InkWell(
        onTap: () => reel.status == ReelStatus.published
            ? context.push(
                RoutePaths.withParams(RoutePaths.reelDetail, {
                  'reelId': reel.id,
                }),
              )
            : _showOwnReelSheet(context, reel),
        onLongPress: own ? () => _showOwnReelSheet(context, reel) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: DashuriTokens.neutral800),
            if (thumb != null)
              Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            else
              const Icon(Icons.movie_outlined, color: Colors.white54),
            if (own && reel.status != ReelStatus.published)
              Positioned(
                left: 4,
                top: 4,
                right: 4,
                child: Align(
                  alignment: Alignment.topLeft,
                  // Grid tiles can be ~110 dp wide: scale the tag down
                  // rather than overflow.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: StatusTag(
                      label: reelStatusLabel(reel.status),
                      tone: reelStatusTone(reel.status),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              bottom: 4,
              child: Row(
                children: [
                  const Icon(Icons.play_arrow, size: 14, color: Colors.white),
                  Text(
                    DashuriFormat.count(reel.viewCount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOwnReelSheet(BuildContext context, Reel reel) {
  final cubit = context.read<CreatorProfileCubit>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DashuriTokens.space4,
          0,
          DashuriTokens.space4,
          DashuriTokens.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: StatusTag(
                    label: reelStatusLabel(reel.status),
                    tone: reelStatusTone(reel.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DashuriTokens.space3),
            Text(switch (reel.status) {
              ReelStatus.awaitingUpload || ReelStatus.processing =>
                "We're preparing your video. This usually takes under a minute.",
              ReelStatus.pendingModeration || ReelStatus.inReview =>
                'Your reel is in a safety review. Only you can see it until it is approved.',
              ReelStatus.published => 'Your reel is live.',
              ReelStatus.rejected ||
              ReelStatus.removed ||
              ReelStatus.failed => rejectionMessage(reel.rejectionCode),
              ReelStatus.deleted => 'This reel was deleted.',
            }),
            if (reel.caption.isNotEmpty) ...[
              const SizedBox(height: DashuriTokens.space2),
              Text(
                '“${reel.caption}”',
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: DashuriTokens.space4),
            if (reel.status.isAppealable &&
                reel.rejectionCode != 'duration_out_of_range')
              OutlinedButton.icon(
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Appeal this decision'),
                onPressed: () async {
                  Navigator.pop(sheet);
                  final text = await _askAppeal(context);
                  if (text != null) await cubit.appeal(reel.id, text);
                },
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(sheet).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete reel'),
              onPressed: () async {
                Navigator.pop(sheet);
                final ok = await showConfirmDialog(
                  context,
                  title: 'Delete this reel?',
                  message:
                      'It will be removed from Dashuri. This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok) await cubit.deleteReel(reel.id);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> _askAppeal(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      // The 5-line field must stay reachable above the keyboard.
      scrollable: true,
      title: const Text('Appeal'),
      content: TextField(
        controller: controller,
        maxLength: 2000,
        maxLines: 5,
        minLines: 3,
        decoration: const InputDecoration(
          hintText: 'Tell the moderator why this reel follows the rules.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = controller.text.trim();
            if (t.isNotEmpty) Navigator.pop(d, t);
          },
          child: const Text('Send appeal'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
