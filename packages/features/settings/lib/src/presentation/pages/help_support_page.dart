import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/grievance_cubit.dart';
import '../../domain/usecases/settings_usecases.dart';
import '../widgets/settings_list.dart';

/// S07 help & support / Safety Centre, support email (D-22) and the
/// in-app grievance form.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({required this.supportEmail, super.key});

  /// From `AppConfig.supportEmail`; empty when not configured.
  final String supportEmail;

  static const _topics = [
    (
      Icons.diamond_outlined,
      'Diamonds & payments',
      'Diamonds are bought in the Wallet and used for video calls. Your '
          'balance and every purchase are listed under Wallet › '
          'Transactions. If a payment fails, no Diamonds are added and no '
          'money is taken; any amount debited by your bank is reversed by '
          'the payment provider.',
    ),
    (
      Icons.videocam_outlined,
      'Calls & billing',
      'Calls are billed per minute at the host’s rate, measured by our '
          'servers from the moment video connects. If a call never connects, '
          'nothing is charged. Each call summary shows the exact Diamonds '
          'used.',
    ),
    (
      Icons.chat_bubble_outline,
      'Chats & messages',
      'You can message hosts you are allowed to chat with. Phone numbers, '
          'links and payment details are blocked to keep everyone safe. '
          'Control who can message you in Settings › Privacy.',
    ),
    (
      Icons.person_outline,
      'Account & verification',
      'Your account is linked to one verified phone number. You can edit '
          'your name, photo and city in your profile. Contact support to '
          'correct your date of birth.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: SettingsList(
        children: [
          const SizedBox(height: DashuriTokens.space4),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(DashuriTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: DashuriTokens.space2),
                      Expanded(
                        child: Text(
                          'Safety Centre',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DashuriTokens.space2),
                  Text(
                    'To report someone, open their profile, chat or call and '
                    'tap Report. Anyone who seems under 18 should always be '
                    'reported. Never share phone numbers or payment details.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => context.push(RoutePaths.blockedUsers),
                        child: const Text('Blocked users'),
                      ),
                      TextButton(
                        onPressed: () => context.push(RoutePaths.enforcement),
                        child: const Text('Account status'),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '${RoutePaths.legal}?doc=child_safety',
                        ),
                        child: const Text('Child safety'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Topics'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (icon, title, body) in _topics)
                  ExpansionTile(
                    leading: Icon(icon),
                    title: Text(title),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      DashuriTokens.space5,
                      0,
                      DashuriTokens.space5,
                      DashuriTokens.space4,
                    ),
                    children: [Text(body, style: theme.textTheme.bodyMedium)],
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Still need help?'),
          _SupportEmailCard(email: supportEmail),
          const SizedBox(height: DashuriTokens.space4),
          const _GrievanceForm(),
        ],
      ),
    );
  }
}

class _SupportEmailCard extends StatelessWidget {
  const _SupportEmailCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    if (email.isEmpty) {
      return const InfoBanner(
        tone: InfoBannerTone.warning,
        message:
            'The support email is not configured in this build. Use the '
            'form below to reach us.',
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.mail_outline),
        title: const Text('Email support'),
        subtitle: SelectableText(email),
        trailing: IconButton(
          tooltip: 'Copy email address',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email address copied')),
              );
            }
          },
        ),
      ),
    );
  }
}

class _GrievanceForm extends StatefulWidget {
  const _GrievanceForm();

  @override
  State<_GrievanceForm> createState() => _GrievanceFormState();
}

class _GrievanceFormState extends State<_GrievanceForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<GrievanceCubit, GrievanceState>(
      builder: (context, state) {
        final cubit = context.read<GrievanceCubit>();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(DashuriTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Raise a complaint or grievance',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tell us what went wrong. Complaints under the IT Rules are '
                  'acknowledged within 24 hours.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: DashuriTokens.space3),
                if (state.submitted)
                  InfoBanner(
                    tone: InfoBannerTone.success,
                    message:
                        "Thanks, we've received your complaint and will "
                        'reply in the app.'
                        '${state.referenceId == null ? '' : ' Reference: ${state.referenceId}'}',
                  )
                else ...[
                  TextField(
                    controller: _controller,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: grievanceMaxLength,
                    onChanged: cubit.changed,
                    decoration: const InputDecoration(
                      labelText: 'Describe the problem',
                      helperText: 'At least 10 characters.',
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (state.failure != null) ...[
                    const SizedBox(height: DashuriTokens.space2),
                    InfoBanner(
                      tone: InfoBannerTone.error,
                      message: failureMessage(state.failure!),
                    ),
                  ],
                  const SizedBox(height: DashuriTokens.space3),
                  PrimaryButton(
                    label: 'Send',
                    busy: state.submitting,
                    onPressed: state.canSubmit ? cubit.submit : null,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
