import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/privacy_cubit.dart';
import '../../domain/entities/messaging_privacy.dart';
import '../widgets/settings_list.dart';

/// S04 privacy: who can message me.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: BlocConsumer<PrivacyCubit, PrivacyState>(
        listenWhen: (a, b) =>
            b.saveFailure != null && a.saveFailure != b.saveFailure,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Couldn't change this. ${failureMessage(state.saveFailure!)}",
                ),
              ),
            ),
        builder: (context, state) {
          final cubit = context.read<PrivacyCubit>();
          return switch (state.status) {
            PrivacyStatus.loading => const LoadingView(),
            PrivacyStatus.failed => ErrorStateView(
              title: "Couldn't load these settings",
              message: failureMessage(state.failure!),
              onRetry: cubit.load,
            ),
            PrivacyStatus.ready => SettingsList(
              children: [
                const SizedBox(height: DashuriTokens.space4),
                Semantics(
                  header: true,
                  child: Text(
                    'Who can message me',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose who can start a chat with you. Existing chats '
                  'follow the new rule.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DashuriTokens.space4),
                for (final w in WhoCanMessage.values) ...[
                  ChoiceCard(
                    title: w.label,
                    subtitle: w.description,
                    selected: state.value == w,
                    onTap: state.saving ? null : () => cubit.select(w),
                  ),
                  const SizedBox(height: DashuriTokens.space2),
                ],
                SettingsGroup(
                  title: 'Safety',
                  children: [
                    SettingsTile(
                      icon: Icons.block,
                      title: 'Blocked users',
                      onTap: () => context.push(RoutePaths.blockedUsers),
                    ),
                    SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Safety Centre',
                      onTap: () => context.push(RoutePaths.helpSupport),
                    ),
                  ],
                ),
              ],
            ),
          };
        },
      ),
    );
  }
}
