import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/arrival_photo_cubit.dart';
import '../../domain/entities/arrival_photo.dart';
import 'session_copy.dart';

/// The optional arrival-photo step of going online: prompt → camera →
/// preview (Retake / Use photo). Shown as a sheet; Skip always works and
/// never affects going online.
class ArrivalPromptSheet extends StatelessWidget {
  const ArrivalPromptSheet({required this.onDone, super.key});

  /// Called once the host confirmed a photo or skipped.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ArrivalPhotoCubit>();
    return BlocConsumer<ArrivalPhotoCubit, ArrivalState>(
      listenWhen: (a, b) => b is ArrivalConfirmed || b is ArrivalSkipped,
      listener: (_, _) => onDone(),
      builder: (context, s) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DashuriTokens.space5,
            0,
            DashuriTokens.space5,
            DashuriTokens.space5,
          ),
          child: switch (s) {
            ArrivalPreview(:final photo) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Use this photo?', style: theme.textTheme.titleLarge),
                const SizedBox(height: DashuriTokens.space3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .45,
                    ),
                    child: Image.memory(
                      photo.bytes,
                      key: const Key('arrival-preview'),
                      fit: BoxFit.contain,
                      semanticLabel: 'Your new arrival photo',
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 160,
                        child: Center(child: Text("Preview couldn't be shown")),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DashuriTokens.space3),
                Text(
                  'Customers will see it as a recent photo ("Captured a few '
                  'minutes ago") while you are online. It is removed when '
                  'you go offline.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: DashuriTokens.space4),
                PrimaryButton(
                  label: 'Use photo',
                  icon: Icons.check_rounded,
                  onPressed: cubit.confirm,
                ),
                const SizedBox(height: DashuriTokens.space2),
                OutlinedButton.icon(
                  onPressed: cubit.retake,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retake'),
                ),
              ],
            ),
            ArrivalCapturing() => const SizedBox(
              height: 200,
              child: LoadingView(message: 'Opening camera…'),
            ),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: HostArrivalIcon()),
                const SizedBox(height: DashuriTokens.space3),
                Text(
                  'Add an arrival photo?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  'Take a quick selfie so customers can see how you look '
                  'today. It is optional — skipping never affects your '
                  'calls or ranking.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: DashuriTokens.space5),
                PrimaryButton(
                  label: 'Capture photo',
                  icon: Icons.photo_camera_front_rounded,
                  onPressed: cubit.capture,
                ),
                const SizedBox(height: DashuriTokens.space2),
                TextButton(onPressed: cubit.skip, child: const Text('Skip')),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class HostArrivalIcon extends StatelessWidget {
  const HostArrivalIcon({super.key});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 32,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(
      Icons.photo_camera_front_rounded,
      size: 32,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}

/// The current session's arrival photo on Host Home.
class ArrivalPhotoCard extends StatelessWidget {
  const ArrivalPhotoCard({
    required this.now,
    required this.onRetake,
    super.key,
  });

  final DateTime now;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ArrivalPhotoCubit>();
    return BlocBuilder<ArrivalPhotoCubit, ArrivalState>(
      builder: (context, s) {
        final (photo, busy, failure) = switch (s) {
          ArrivalLoaded(:final current) => (current, false, null),
          ArrivalUploading() || ArrivalConfirmed() => (null, true, null),
          final ArrivalFailed f => (null, false, f),
          _ => (null, false, null),
        };
        final (label, tone) = switch (photo?.status) {
          ArrivalPhotoStatus.approved => (
            'Visible to customers',
            StatusTone.success,
          ),
          ArrivalPhotoStatus.pendingReview => ('In review', StatusTone.warning),
          ArrivalPhotoStatus.rejected => ('Not approved', StatusTone.error),
          _ => ('', StatusTone.neutral),
        };
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
              child: SizedBox.square(
                dimension: 72,
                child: photo?.photoUrl != null
                    ? Image.network(
                        photo!.photoUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Your arrival photo',
                        errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                      )
                    : const _PhotoPlaceholder(),
              ),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arrival photo', style: theme.textTheme.titleSmall),
                  const SizedBox(height: DashuriTokens.space1),
                  if (busy)
                    const Text('Uploading…')
                  else if (failure != null) ...[
                    Text(
                      arrivalFailureMessage(failure.failure),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (failure.retryable)
                      TextButton(
                        onPressed: cubit.upload,
                        child: const Text('Try again'),
                      ),
                  ] else if (photo == null)
                    Text(
                      'Optional. A fresh selfie for this session helps customers decide.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...[
                    StatusTag(label: label, tone: tone),
                    if (photo.capturedAt != null) ...[
                      const SizedBox(height: DashuriTokens.space1),
                      Text(
                        capturedAgo(photo.capturedAt!, now),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (photo.status == ArrivalPhotoStatus.rejected &&
                        photo.reason != null)
                      Text(
                        "It couldn't be shown (${photo.reason}).",
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                  Wrap(
                    spacing: DashuriTokens.space2,
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : onRetake,
                        icon: const Icon(Icons.photo_camera_front_rounded),
                        label: Text(photo == null ? 'Take photo' : 'Retake'),
                      ),
                      if (photo != null)
                        TextButton(
                          onPressed: cubit.removeCurrent,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: Icon(
      Icons.person_outline_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
