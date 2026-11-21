import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/report_cubit.dart';
import '../../domain/entities/report_category.dart';
import '../widgets/safety_copy.dart';

/// V11 report form and V12 confirmation, at
/// `RoutePaths.report?userId=…&callId=…&name=…`. Pops with `true` when the
/// report was submitted.
class ReportPage extends StatelessWidget {
  const ReportPage({required this.name, super.key, this.fromCall = false});

  final String name;

  /// Shows the "reporting during a call ends it" notice.
  final bool fromCall;

  void _close(BuildContext context, bool submitted) {
    if (context.canPop()) {
      context.pop(submitted);
    } else {
      context.go(RoutePaths.discovery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportCubit, ReportState>(
      builder: (context, state) => state.submitted
          ? _SubmittedView(
              name: name,
              state: state,
              onDone: () => _close(context, true),
            )
          : _form(context, state),
    );
  }

  Widget _form(BuildContext context, ReportState state) {
    final theme = Theme.of(context);
    final cubit = context.read<ReportCubit>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => _close(context, false),
        ),
        title: Text('Report $name', overflow: TextOverflow.ellipsis),
      ),
      body: FormPageBody(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.failure != null) ...[
              InfoBanner(
                tone: InfoBannerTone.error,
                message: safetyFailureMessage(state.failure!),
              ),
              const SizedBox(height: DashuriTokens.space3),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: state.canSubmit ? cubit.submit : null,
                child: state.submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit report'),
              ),
            ),
          ],
        ),
        children: [
          if (fromCall) ...[
            const SizedBox(height: DashuriTokens.space2),
            const InfoBanner(
              message:
                  'Reporting during a call ends it immediately. A still frame '
                  'is kept privately for our safety team.',
            ),
          ],
          const SizedBox(height: DashuriTokens.space5),
          Semantics(
            header: true,
            child: Text('What happened?', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: DashuriTokens.space3),
          Card(
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<ReportCategory>(
              groupValue: state.category,
              onChanged: (c) {
                if (c != null) cubit.selectCategory(c);
              },
              child: Column(
                children: [
                  for (final c in ReportCategory.values)
                    RadioListTile<ReportCategory>(
                      value: c,
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text(c.label),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DashuriTokens.space4),
          TextField(
            minLines: 3,
            maxLines: 6,
            maxLength: reportDetailsMaxLength,
            onChanged: cubit.setDetails,
            decoration: const InputDecoration(
              hintText: 'Add details (optional)',
              labelText: 'Details',
              alignLabelWithHint: true,
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: state.alsoBlock,
            onChanged: (v) => cubit.setAlsoBlock(v ?? false),
            title: Text('Also block $name'),
          ),
        ],
      ),
    );
  }
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({
    required this.name,
    required this.state,
    required this.onDone,
  });

  final String name;
  final ReportState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pageGutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: DashuriTokens.success100,
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 40,
                      color: DashuriTokens.success,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space5),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      'Thanks for telling us',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space3),
                  Text(
                    "Our safety team will review this report. We'll let you "
                    'know when action has been taken.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: DashuriTokens.space5),
                  if (state.blocked)
                    Card(
                      child: ListTile(
                        leading: UserAvatar(name: name, radius: 18),
                        title: Text('$name is blocked'),
                        trailing: const StatusTag(
                          label: 'Blocked',
                          tone: StatusTone.neutral,
                        ),
                      ),
                    )
                  else if (state.failure != null)
                    InfoBanner(
                      tone: InfoBannerTone.warning,
                      message:
                          "Your report was sent, but we couldn't block $name. "
                          '${safetyFailureMessage(state.failure!)}',
                    ),
                  const SizedBox(height: DashuriTokens.space6),
                  PrimaryButton(label: 'Done', onPressed: onDone),
                  TextButton(
                    onPressed: () => context.push(RoutePaths.helpSupport),
                    child: const Text('Visit Safety Centre'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
