import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/verified_host_cubit.dart';
import '../../domain/entities/host_verification.dart';
import '../../domain/ports/verification_media_picker.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// Verified Host application and status (RoutePaths.hostVerifiedHost).
/// Evidence goes to a private bucket for staff review only.
class VerifiedHostPage extends StatelessWidget {
  const VerifiedHostPage({super.key, this.picker});

  /// Registered by the app; null in builds without camera access.
  final VerificationMediaPicker? picker;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<VerifiedHostCubit, VerifiedHostState>(
        listenWhen: (a, b) =>
            a.failure != b.failure || a.submitted != b.submitted,
        listener: (context, state) {
          if (state.failure != null) {
            showHostSnack(context, hostFailureMessage(state.failure!));
          } else if (state.submitted) {
            showHostSnack(context, 'Sent for review. We will let you know.');
          }
        },
        builder: (context, state) {
          final cubit = context.read<VerifiedHostCubit>();
          final v = state.verification;
          return Scaffold(
            appBar: AppBar(title: const Text('Verified Host')),
            body: switch (state.status) {
              VerifiedHostStatus.loading => const LoadingView(),
              VerifiedHostStatus.loadFailed => ErrorStateView(
                title: "Couldn't load Verified Host",
                message: hostFailureMessage(state.failure!),
                onRetry: cubit.load,
              ),
              _ => _Body(state: state, picker: picker),
            },
            bottomNavigationBar: v == null || !v.canSubmit
                ? null
                : HostBottomBar(
                    children: [
                      PrimaryButton(
                        label: v.replyingToInfoRequest
                            ? 'Send to reviewer'
                            : 'Submit for review',
                        busy: state.status == VerifiedHostStatus.submitting,
                        onPressed:
                            v.readyToSubmit &&
                                state.status == VerifiedHostStatus.ready
                            ? cubit.submit
                            : null,
                      ),
                    ],
                  ),
          );
        },
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.picker});

  final VerifiedHostState state;
  final VerificationMediaPicker? picker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = state.verification!;
    final cubit = context.read<VerifiedHostCubit>();
    final (tone, icon) = switch (v.status) {
      VerificationStatuses.verified => (
        StatusTone.success,
        VerifiedHostBadge.icon,
      ),
      VerificationStatuses.rejected ||
      VerificationStatuses.suspended ||
      VerificationStatuses.revoked => (
        StatusTone.error,
        Icons.gpp_bad_outlined,
      ),
      VerificationStatuses.infoRequired => (
        StatusTone.warning,
        Icons.info_outline_rounded,
      ),
      VerificationStatuses.notApplied => (
        StatusTone.info,
        Icons.shield_outlined,
      ),
      _ => (StatusTone.info, Icons.hourglass_top_rounded),
    };
    return HostFormBody(
      children: [
        if (v.isVerified)
          const Center(child: VerifiedHostBadge(size: 22))
        else
          StatusTag(label: VerificationStatuses.label(v.status), tone: tone),
        const SizedBox(height: DashuriTokens.space4),
        Text(
          v.isVerified
              ? 'Customers see the Verified Host badge on your profile, and you '
                    'can set rates above 3,000 Diamonds per minute (up to your '
                    "level's limit)."
              : 'Verified Hosts get a badge customers can trust and can charge '
                    'more than 3,000 Diamonds per minute (up to their level '
                    'limit). A reviewer checks a short face video against your '
                    'ID document.',
          style: theme.textTheme.bodyLarge,
        ),
        if (v.note != null) ...[
          const SizedBox(height: DashuriTokens.space4),
          HostNotice(tone: tone, icon: icon, message: v.note!),
        ],
        if (v.canSubmit) ...[
          const SizedBox(height: DashuriTokens.space6),
          Text(
            v.replyingToInfoRequest
                ? 'Add what was asked for'
                : 'Your evidence',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: DashuriTokens.space3),
          for (final kind in EvidenceKind.values)
            _EvidenceTile(
              kind: kind,
              done: v.hasPending(kind),
              busy:
                  state.status == VerifiedHostStatus.uploading &&
                  state.uploadingKind == kind,
              onTap: picker == null || state.status != VerifiedHostStatus.ready
                  ? null
                  : () async {
                      final media = kind == EvidenceKind.faceVideo
                          ? await picker!.recordFaceVideo()
                          : await picker!.pickIdImage();
                      await cubit.upload(kind, media);
                    },
            ),
          if (picker == null) ...[
            const SizedBox(height: DashuriTokens.space3),
            const HostNotice(
              tone: StatusTone.warning,
              message: "This build can't capture verification evidence.",
            ),
          ],
        ],
        const SizedBox(height: DashuriTokens.space6),
        const HostNotice(
          icon: Icons.lock_outline_rounded,
          message:
              'Your face video and ID are stored privately, seen only by '
              'Dashuri reviewers, never shown on your profile, and deleted '
              '90 days after a decision. We do not create face templates.',
        ),
      ],
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.kind,
    required this.done,
    required this.busy,
    required this.onTap,
  });

  final EvidenceKind kind;
  final bool done;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      kind == EvidenceKind.faceVideo
          ? Icons.videocam_outlined
          : Icons.badge_outlined,
    ),
    title: Text(kind.label),
    subtitle: Text(done ? 'Uploaded' : 'Not added yet'),
    trailing: busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        : done
        ? const Icon(Icons.check_circle_rounded)
        : const Icon(Icons.chevron_right_rounded),
    onTap: busy ? null : onTap,
  );
}
