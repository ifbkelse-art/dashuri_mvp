import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_account_cubit.dart';

/// S09 consequences + S10 final confirmation (two confirmations: an
/// "I understand" checkbox and a destructive dialog). D-21 rules.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  Future<void> _confirm(BuildContext context, DeleteAccountState state) async {
    final cubit = context.read<DeleteAccountCubit>();
    final diamonds = state.diamonds ?? 0;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete your account?',
      message: diamonds > 0
          ? "This can't be undone after the 7-day grace period. Your "
                '${DashuriFormat.count(diamonds)} Diamonds will be lost.'
          : "This can't be undone after the 7-day grace period.",
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (ok) await cubit.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: BlocBuilder<DeleteAccountCubit, DeleteAccountState>(
        builder: (context, state) => state.request != null
            ? _scheduled(context, state)
            : _explain(context, state),
      ),
    );
  }

  Widget _explain(BuildContext context, DeleteAccountState state) {
    final theme = Theme.of(context);
    final cubit = context.read<DeleteAccountCubit>();
    final diamonds = state.diamonds;
    return FormPageBody(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: state.acknowledged && !state.deleting
                  ? () => _confirm(context, state)
                  : null,
              child: state.deleting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue to delete'),
            ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(RoutePaths.settings),
              child: const Text('Keep my account'),
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: DashuriTokens.space4),
        Semantics(
          header: true,
          child: Text(
            "We're sorry to see you go",
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          "Deleting your account is permanent. Here's what happens:",
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: DashuriTokens.space4),
        for (final (icon, text) in const [
          (
            Icons.person_off_outlined,
            'Your profile, photos and chats are removed',
          ),
          (Icons.block, "You can't log back in with this account"),
          (Icons.schedule, 'You have 7 days to change your mind by logging in'),
          (
            Icons.folder_off_outlined,
            'Some records are kept as required by law',
          ),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(text),
          ),
        const SizedBox(height: DashuriTokens.space2),
        if (!state.balanceLoaded)
          const LinearProgressIndicator()
        else if (diamonds != null && diamonds > 0)
          InfoBanner(
            tone: InfoBannerTone.warning,
            icon: Icons.diamond_outlined,
            message:
                'You still have ${DashuriFormat.count(diamonds)} Diamonds. '
                "Unused Diamonds can't be recovered after deletion.",
          )
        else if (diamonds == null)
          const InfoBanner(
            tone: InfoBannerTone.warning,
            message:
                "We couldn't check your Diamond balance. Any unused Diamonds "
                "can't be recovered after deletion.",
          ),
        if (state.failure != null) ...[
          const SizedBox(height: DashuriTokens.space3),
          InfoBanner(
            tone: InfoBannerTone.error,
            message: state.blockedByBalance
                ? "You can't delete your account while you have Beans on "
                      'hold, available or waiting for payout. Withdraw them '
                      'or wait for the payout to finish, then try again.'
                : failureMessage(state.failure!),
          ),
        ],
        const SizedBox(height: DashuriTokens.space3),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: state.acknowledged,
          onChanged: (v) => cubit.acknowledge(v ?? false),
          title: const Text(
            'I understand that deletion is permanent and unused Diamonds '
            'are lost.',
          ),
        ),
      ],
    );
  }

  Widget _scheduled(BuildContext context, DeleteAccountState state) {
    final theme = Theme.of(context);
    final when = state.request!.scheduledFor?.toLocal();
    return FormPageBody(
      bottom: PrimaryButton(
        label: 'Log out',
        onPressed: context.read<DeleteAccountCubit>().signOut,
      ),
      children: [
        const SizedBox(height: DashuriTokens.space8),
        const Icon(Icons.event_busy_outlined, size: 56),
        const SizedBox(height: DashuriTokens.space4),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Account deletion scheduled',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        Text(
          when == null
              ? 'Your account will be deleted after a 7-day grace period. Log '
                    'in before then to cancel.'
              : 'Your account will be deleted on ${when.day} '
                    '${_months[when.month - 1]} ${when.year}. Log in before '
                    'then to cancel.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
