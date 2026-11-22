import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/age_gate_cubit.dart';

/// A09 date of birth (18+) and A10 blocked state.
class AgeGatePage extends StatelessWidget {
  const AgeGatePage({super.key, this.now});

  /// Today's date (tests inject a fixed date).
  final DateTime? now;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  static String formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _pick(BuildContext context, DateTime? current) async {
    final today = now ?? DateTime.now();
    final cubit = context.read<AgeGateCubit>();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(today.year - 25, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Date of birth',
      fieldLabelText: 'Date of birth',
    );
    if (picked != null) cubit.setDateOfBirth(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgeGateCubit, AgeGateState>(
      builder: (context, state) => state.outcome == AgeGateOutcome.blocked
          ? const _BlockedView()
          : _form(context, state),
    );
  }

  Widget _form(BuildContext context, AgeGateState state) {
    final theme = Theme.of(context);
    final cubit = context.read<AgeGateCubit>();
    final dob = state.dateOfBirth;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: const OnboardingStepBar(step: 3, total: 6),
        ),
      ),
      body: FormPageBody(
        bottom: PrimaryButton(
          label: 'Continue',
          busy: state.submitting,
          onPressed: dob != null && state.confirmed ? cubit.submit : null,
        ),
        children: [
          const SizedBox(height: DashuriTokens.space4),
          Semantics(
            header: true,
            child: Text(
              "When's your birthday?",
              style: theme.textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          Text(
            'Dashuri is only for adults. Your date of birth stays private.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DashuriTokens.space6),
          Semantics(
            button: true,
            label: dob == null
                ? 'Choose your date of birth'
                : 'Date of birth ${formatDate(dob)}. Change',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => _pick(context, dob),
              borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  dob == null ? 'Select date' : formatDate(dob),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ),
          if (state.age != null) ...[
            const SizedBox(height: DashuriTokens.space4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(DashuriTokens.space4),
                child: LabelValueRow(
                  label: Text('Your age', style: theme.textTheme.bodyLarge),
                  value: Text(
                    '${state.age} years',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: DashuriTokens.space4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: state.confirmed,
            onChanged: (v) => cubit.setConfirmed(v ?? false),
            title: const Text(
              'I confirm I am 18 years or older and that the date above is '
              'correct.',
            ),
          ),
          if (state.failure != null) ...[
            const SizedBox(height: DashuriTokens.space3),
            InfoBanner(
              tone: InfoBannerTone.error,
              message: failureMessage(state.failure!),
            ),
          ],
        ],
      ),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView();

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
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space5),
                  Semantics(
                    header: true,
                    child: Text(
                      'Dashuri is for adults only',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space3),
                  Text(
                    "You need to be 18 or older to use Dashuri. We can't "
                    'create an account for you right now.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: DashuriTokens.space6),
                  const PrimaryButton(
                    label: 'Close app',
                    onPressed: SystemNavigator.pop,
                  ),
                  TextButton(
                    onPressed: () =>
                        context.push('${RoutePaths.legal}?doc=child_safety'),
                    child: const Text('Learn about our safety standards'),
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
