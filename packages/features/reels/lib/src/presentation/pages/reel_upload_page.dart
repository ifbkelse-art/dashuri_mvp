import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/reel_upload_cubit.dart';
import '../../domain/entities/reel.dart';
import '../../domain/ports/reel_video_picker.dart';
import 'creator_profile_page.dart' show rejectionMessage;

/// R1 record / R2 gallery → R3 preview + caption → R5 progress → R6/R7
/// processing, safety review, published or rejected.
class ReelUploadPage extends StatefulWidget {
  const ReelUploadPage({super.key});

  @override
  State<ReelUploadPage> createState() => _ReelUploadPageState();
}

class _ReelUploadPageState extends State<ReelUploadPage> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ReelUploadCubit, ReelUploadState>(
    builder: (context, s) => PopScope(
      canPop: s is! UploadSending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Post a reel')),
        body: SafeArea(
          child: switch (s) {
            UploadLoading() => const LoadingView(),
            UploadUnavailable(:final message) => EmptyStateView(
              icon: Icons.videocam_off_outlined,
              title: 'Posting is unavailable',
              message: message,
              actionLabel: 'Back to Reels',
              onAction: () => context.go(RoutePaths.reels),
            ),
            UploadPick(:final config, :final error) => _Body(
              children: [
                Text(
                  'Share a short video',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  '${config.minDurationMs ~/ 1000}–${config.maxDurationMs ~/ 1000} seconds, filmed upright (9:16). '
                  'Every reel gets a safety review before anyone else can see it.',
                ),
                const SizedBox(height: DashuriTokens.space4),
                if (error != null) ...[
                  InfoBanner(message: error, tone: InfoBannerTone.error),
                  const SizedBox(height: DashuriTokens.space4),
                ],
                PrimaryButton(
                  label: 'Record video',
                  icon: Icons.videocam_outlined,
                  onPressed: () => context.read<ReelUploadCubit>().pick(
                    ReelVideoSource.camera,
                  ),
                ),
                const SizedBox(height: DashuriTokens.space3),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                  onPressed: () => context.read<ReelUploadCubit>().pick(
                    ReelVideoSource.gallery,
                  ),
                ),
                const SizedBox(height: DashuriTokens.space6),
                const _Rules(),
              ],
            ),
            UploadPreview(
              :final config,
              :final video,
              :final durationMs,
              :final error,
            ) =>
              _Body(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 72,
                        height: 128,
                        decoration: BoxDecoration(
                          color: DashuriTokens.neutral800,
                          borderRadius: BorderRadius.circular(
                            DashuriTokens.space2,
                          ),
                        ),
                        child: const Icon(
                          Icons.movie_outlined,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: DashuriTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Video ready',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${(durationMs / 1000).toStringAsFixed(1)} s · ${_mb(video.bytes.length)}',
                            ),
                            TextButton(
                              onPressed: context
                                  .read<ReelUploadCubit>()
                                  .discard,
                              child: const Text('Choose a different video'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DashuriTokens.space4),
                  TextField(
                    controller: _caption,
                    maxLength: config.maxCaptionLength,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Caption',
                      hintText: 'Say something about your reel',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: DashuriTokens.space2),
                    InfoBanner(message: error, tone: InfoBannerTone.error),
                  ],
                  const SizedBox(height: DashuriTokens.space4),
                  const InfoBanner(
                    message:
                        'Do not include phone numbers, payment IDs, other people without consent, '
                        'or music you do not have rights to.',
                  ),
                  const SizedBox(height: DashuriTokens.space4),
                  PrimaryButton(
                    label: error == null ? 'Post reel' : 'Try again',
                    icon: Icons.upload,
                    onPressed: () =>
                        context.read<ReelUploadCubit>().submit(_caption.text),
                  ),
                ],
              ),
            UploadSending(:final progress) => _Body(
              children: [
                Text(
                  'Uploading…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: DashuriTokens.space4),
                LinearProgressIndicator(value: progress <= 0 ? null : progress),
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  progress <= 0 ? 'Starting' : '${(progress * 100).round()}%',
                ),
                const SizedBox(height: DashuriTokens.space4),
                const Text('Keep the app open until the upload finishes.'),
              ],
            ),
            UploadTracking(:final reel, :final polling) => _Body(
              children: [
                _Timeline(reel: reel),
                const SizedBox(height: DashuriTokens.space4),
                if (reel.status == ReelStatus.awaitingUpload)
                  Text(
                    polling
                        ? 'Confirming your upload with the server…'
                        : "We couldn't confirm the upload yet. If it arrived, "
                              'it will appear in My reels; otherwise post it '
                              'again.',
                  )
                else if (polling && reel.status.isInFlight)
                  const Text(
                    'You can leave this screen. Your reel keeps processing.',
                  )
                else if (reel.status.isInFlight)
                  const Text(
                    "Still in review. We'll keep it in My reels with its status.",
                  ),
                const SizedBox(height: DashuriTokens.space6),
                PrimaryButton(
                  label: 'View my reels',
                  onPressed: () => context.pushReplacement(RoutePaths.reelMine),
                ),
                const SizedBox(height: DashuriTokens.space3),
                OutlinedButton(
                  onPressed: () {
                    _caption.clear();
                    context.read<ReelUploadCubit>().startOver();
                  },
                  child: const Text('Post another'),
                ),
              ],
            ),
          },
        ),
      ),
    ),
  );
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _Body extends StatelessWidget {
  const _Body({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.symmetric(
      horizontal: context.pageGutter,
      vertical: DashuriTokens.space6,
    ),
    child: ResponsiveCenter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget rule(IconData i, String s) => Padding(
      padding: const EdgeInsets.only(bottom: DashuriTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 20),
          const SizedBox(width: DashuriTokens.space2),
          Expanded(child: Text(s)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reels rules', style: t.titleSmall),
        const SizedBox(height: DashuriTokens.space2),
        rule(
          Icons.no_adult_content,
          'No nudity or sexual content. Everyone on camera must be 18+.',
        ),
        rule(
          Icons.music_off_outlined,
          'Only music and clips you own or have the rights to.',
        ),
        rule(
          Icons.privacy_tip_outlined,
          "No one else's private information, and no contact details.",
        ),
        rule(
          Icons.gavel_outlined,
          'If a reel is not approved, you can appeal from My reels.',
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.reel});
  final Reel reel;

  @override
  Widget build(BuildContext context) {
    final s = reel.status;
    // awaiting_upload: the server has not confirmed the file, so "Uploaded"
    // is not ticked yet.
    final step = switch (s) {
      ReelStatus.awaitingUpload => 0,
      ReelStatus.processing => 1,
      ReelStatus.pendingModeration || ReelStatus.inReview => 2,
      _ => 3,
    };
    final failed =
        s == ReelStatus.rejected ||
        s == ReelStatus.removed ||
        s == ReelStatus.failed;
    Widget row(int i, String label, {String? detail}) {
      final done = step > i || (step == 3 && i == 3 && !failed);
      final current = step == i && !(i == 3);
      final icon = failed && i == 3
          ? Icons.cancel
          : done
          ? Icons.check_circle
          : current
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked;
      final color = failed && i == 3
          ? Theme.of(context).colorScheme.error
          : done
          ? DashuriColors.of(context).success.icon
          : null;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: detail == null ? null : Text(detail),
        trailing: current
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failed
              ? 'Your reel was not published'
              : s == ReelStatus.published
              ? 'Your reel is live'
              : s == ReelStatus.awaitingUpload
              ? 'Confirming your upload'
              : 'Uploaded',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: DashuriTokens.space2),
        row(0, 'Uploaded'),
        row(1, 'Processing video'),
        row(
          2,
          'Safety review',
          detail: step == 2
              ? 'Only you can see it until it is approved.'
              : null,
        ),
        row(
          3,
          failed ? 'Not published' : 'Published',
          detail: failed ? rejectionMessage(reel.rejectionCode) : null,
        ),
      ],
    );
  }
}
