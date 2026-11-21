import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/create_profile_cubit.dart';
import '../../application/profile_failure.dart';
import '../../domain/entities/profile.dart';

/// A08 display name and A11 gender, one onboarding step.
class CreateProfilePage extends StatelessWidget {
  const CreateProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<CreateProfileCubit, CreateProfileState>(
      builder: (context, state) {
        final cubit = context.read<CreateProfileCubit>();
        final showLength = state.name.isNotEmpty && !state.nameValid;
        final otherError = state.failure != null && !state.nameRejected
            ? failureMessage(state.failure!)
            : null;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: const OnboardingStepBar(step: 4, total: 6),
            ),
          ),
          body: FormPageBody(
            bottom: PrimaryButton(
              label: 'Continue',
              busy: state.submitting,
              onPressed: state.canSubmit ? cubit.submit : null,
            ),
            children: [
              const SizedBox(height: DashuriTokens.space4),
              Semantics(
                header: true,
                child: Text(
                  'How should we call you?',
                  style: theme.textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                "This is how you'll appear to hosts.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DashuriTokens.space6),
              TextField(
                autofocus: true,
                onChanged: cubit.nameChanged,
                maxLength: displayNameMaxLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  helperText:
                      'Use your first name or a nickname. No phone numbers '
                      'or links.',
                  helperMaxLines: 2,
                  errorMaxLines: 3,
                  errorText: state.nameRejected
                      ? profileTextRejectedMessage
                      : showLength
                      ? 'Use $displayNameMinLength–$displayNameMaxLength '
                            'characters.'
                      : null,
                ),
              ),
              const SizedBox(height: DashuriTokens.space6),
              Semantics(
                header: true,
                child: Text(
                  'How do you identify?',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                'This stays private. It helps us keep Dashuri safe and '
                'relevant for you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DashuriTokens.space4),
              for (final g in Gender.values) ...[
                ChoiceCard(
                  title: g.label,
                  selected: state.gender == g,
                  onTap: () => cubit.genderSelected(g),
                ),
                const SizedBox(height: DashuriTokens.space2),
              ],
              if (otherError != null) ...[
                const SizedBox(height: DashuriTokens.space3),
                InfoBanner(tone: InfoBannerTone.error, message: otherError),
              ],
            ],
          ),
        );
      },
    );
  }
}
