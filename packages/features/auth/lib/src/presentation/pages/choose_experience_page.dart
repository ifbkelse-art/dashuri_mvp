import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/experience_cubit.dart';
import '../widgets/auth_scaffold.dart';

/// A12 choose your experience. "Become a host" starts the host application
/// (`RoutePaths.hostOnboarding`); approved hosts can switch to the host shell.
class ChooseExperiencePage extends StatelessWidget {
  const ChooseExperiencePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<ExperienceCubit, ExperienceState>(
      listenWhen: (a, b) => !a.saved && b.saved,
      listener: (context, state) {
        final host = state.selected == ExperienceMode.host;
        context.go(
          !host
              ? RoutePaths.discovery
              : state.hostModeAvailable
              ? RoutePaths.hostDashboard
              : RoutePaths.hostOnboarding,
        );
      },
      builder: (context, state) {
        final cubit = context.read<ExperienceCubit>();
        return AuthScaffold(
          title: 'How will you use Dashuri?',
          subtitle: 'You can change this later from your profile.',
          showBack: false,
          bottom: PrimaryButton(
            label: 'Continue',
            busy: state.saving,
            onPressed: cubit.confirm,
          ),
          children: [
            ChoiceCard(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.videocam_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: 'Talk with hosts',
              subtitle:
                  'Browse verified hosts who are online and start a private '
                  'video call.',
              selected: state.selected == ExperienceMode.customer,
              onTap: () => cubit.select(ExperienceMode.customer),
            ),
            const SizedBox(height: DashuriTokens.space3),
            ChoiceCard(
              leading: const BeanIcon(size: 32),
              title: state.hostModeAvailable ? 'Host mode' : 'Become a host',
              subtitle: state.hostModeAvailable
                  ? 'Go online and take calls from your host dashboard.'
                  : 'Earn Beans for your time on video calls. Go online '
                        'whenever you like. ID and selfie verification '
                        'required.',
              selected: state.selected == ExperienceMode.host,
              onTap: () => cubit.select(ExperienceMode.host),
            ),
          ],
        );
      },
    );
  }
}
