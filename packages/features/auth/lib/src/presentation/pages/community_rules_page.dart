import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/community_rules_cubit.dart';
import '../../application/session_cubit.dart';
import '../widgets/auth_scaffold.dart';

/// A13 community rules and consent (POST /v1/me/rules-acceptance).
/// Wording is a draft pending legal review (D-12).
class CommunityRulesPage extends StatelessWidget {
  const CommunityRulesPage({super.key});

  static const _rules = [
    (
      Icons.volunteer_activism_outlined,
      'Be kind and respectful',
      "Treat every person on a call the way you'd want to be treated.",
    ),
    (
      Icons.visibility_off_outlined,
      'No nudity or sexual content',
      'Calls are checked for safety. Breaking this rule leads to removal.',
    ),
    (
      Icons.phone_disabled_outlined,
      'Keep it on Dashuri',
      "Don't share phone numbers, social handles or payment details.",
    ),
    (
      Icons.verified_user_outlined,
      'Adults only, always',
      'Report anyone who seems under 18. We act on every report.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<CommunityRulesCubit, CommunityRulesState>(
      listenWhen: (a, b) => b.accepted != null && a.accepted != b.accepted,
      listener: (context, state) =>
          context.read<SessionCubit>().applyAccount(state.accepted!),
      builder: (context, state) => AuthScaffold(
        step: 5,
        showBack: false,
        title: 'Our promise to each other',
        subtitle: 'Before you start',
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.failure != null) ...[
              InfoBanner(
                tone: InfoBannerTone.error,
                message: failureMessage(state.failure!),
              ),
              const SizedBox(height: DashuriTokens.space3),
            ],
            PrimaryButton(
              label: 'I agree',
              busy: state.submitting,
              onPressed: () => context.read<CommunityRulesCubit>().accept(),
            ),
          ],
        ),
        children: [
          for (final (icon, title, body) in _rules) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(DashuriTokens.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(icon, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: DashuriTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(body, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: DashuriTokens.space3),
          ],
          const SizedBox(height: DashuriTokens.space2),
          Text(
            'By tapping "I agree" you accept the Terms of Service, Community '
            'Guidelines and Privacy Policy.',
            style: theme.textTheme.bodySmall,
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () => context.push('${RoutePaths.legal}?doc=terms'),
                child: const Text('Terms of Service'),
              ),
              TextButton(
                onPressed: () =>
                    context.push('${RoutePaths.legal}?doc=community'),
                child: const Text('Community Guidelines'),
              ),
              TextButton(
                onPressed: () =>
                    context.push('${RoutePaths.legal}?doc=privacy'),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
