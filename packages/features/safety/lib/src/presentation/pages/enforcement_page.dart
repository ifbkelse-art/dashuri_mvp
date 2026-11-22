import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/enforcement_cubit.dart';
import '../../domain/entities/enforcement_notice.dart';
import '../../domain/entities/report_category.dart';
import '../widgets/safety_copy.dart';

/// Account status: enforcement notices and appeals (`RoutePaths.enforcement`).
class EnforcementPage extends StatelessWidget {
  const EnforcementPage({super.key});

  static String actionLabel(String action) => switch (action) {
    'warning' => 'Warning',
    'suspended' || 'suspension' => 'Account suspended',
    'banned' || 'ban' => 'Account banned',
    'content_removed' => 'Content removed',
    'call_ended' => 'Call ended for safety',
    _ => action.replaceAll('_', ' '),
  };

  Future<void> _appeal(BuildContext context, EnforcementNotice n) async {
    final cubit = context.read<EnforcementCubit>();
    final statement = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AppealSheet(),
    );
    if (statement != null) await cubit.appeal(n.id, statement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account status')),
      body: BlocConsumer<EnforcementCubit, EnforcementState>(
        listenWhen: (a, b) =>
            (b.appealFailure != null && a.appealFailure != b.appealFailure) ||
            b.appealed.length > a.appealed.length,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.appealFailure != null
                    ? safetyFailureMessage(state.appealFailure!)
                    : "Appeal sent. We'll review it and let you know.",
              ),
            ),
          );
        },
        builder: (context, state) => switch (state.status) {
          EnforcementStatus.loading => const LoadingView(),
          EnforcementStatus.failed => ErrorStateView(
            message: failureMessage(state.failure!),
            onRetry: context.read<EnforcementCubit>().load,
          ),
          EnforcementStatus.loaded when state.notices.isEmpty =>
            const EmptyStateView(
              icon: Icons.verified_user_outlined,
              title: 'Your account is in good standing',
              message: 'There are no warnings or restrictions on your account.',
            ),
          EnforcementStatus.loaded => ListView(
            padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space4),
            children: [
              for (final n in state.notices)
                ResponsiveCenter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: DashuriTokens.space3,
                    ),
                    child: _NoticeCard(
                      notice: n,
                      appealing: state.appealing == n.id,
                      appealed: state.appealed.contains(n.id),
                      onAppeal: () => _appeal(context, n),
                    ),
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.appealing,
    required this.appealed,
    required this.onAppeal,
  });

  final EnforcementNotice notice;
  final bool appealing;
  final bool appealed;
  final VoidCallback onAppeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = notice.createdAt.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DashuriTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabelValueRow(
              label: Text(
                EnforcementPage.actionLabel(notice.action),
                style: theme.textTheme.titleMedium,
              ),
              value: Text(
                '${d.day}/${d.month}/${d.year}',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: DashuriTokens.space2),
            Text(notice.reason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: DashuriTokens.space3),
            if (appealed)
              const StatusTag(label: 'Appeal sent', tone: StatusTone.info)
            else if (notice.appealable)
              OutlinedButton(
                onPressed: appealing ? null : onAppeal,
                child: appealing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Appeal this decision'),
              )
            else
              Text(
                'This decision cannot be appealed.',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _AppealSheet extends StatefulWidget {
  const _AppealSheet();

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        left: DashuriTokens.space5,
        right: DashuriTokens.space5,
        bottom: MediaQuery.viewInsetsOf(context).bottom + DashuriTokens.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Appeal this decision', style: theme.textTheme.titleLarge),
            const SizedBox(height: DashuriTokens.space2),
            Text(
              'Tell us why you think this was a mistake. A person on our '
              'safety team will review it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DashuriTokens.space4),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: appealStatementMaxLength,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Your statement',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: DashuriTokens.space3),
            PrimaryButton(
              label: 'Send appeal',
              onPressed: text.isEmpty
                  ? null
                  : () => Navigator.pop(context, _controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
