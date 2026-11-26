import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/blocked_users_cubit.dart';
import '../../domain/entities/blocked_user.dart';
import '../widgets/safety_copy.dart';

/// S06 blocked users with unblock.
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String blockedOn(DateTime d) {
    final l = d.toLocal();
    return 'Blocked ${l.day} ${_months[l.month - 1]}';
  }

  Future<void> _confirmUnblock(BuildContext context, BlockedUser u) async {
    final cubit = context.read<BlockedUsersCubit>();
    final ok = await showConfirmDialog(
      context,
      title: 'Unblock ${u.displayName}?',
      message:
          'They will be able to see your profile, call and message you '
          "again. They won't be notified.",
      confirmLabel: 'Unblock',
    );
    if (ok) await cubit.unblock(u.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: BlocConsumer<BlockedUsersCubit, BlockedUsersState>(
        listenWhen: (a, b) =>
            b is BlockedUsersStateLoaded && b.actionFailure != null,
        listener: (context, state) {
          final failure = (state as BlockedUsersStateLoaded).actionFailure!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safetyFailureMessage(failure))),
          );
        },
        builder: (context, state) => switch (state) {
          BlockedUsersStateInitial() ||
          BlockedUsersStateLoading() => const LoadingView(),
          BlockedUsersStateFailed(:final failure) => ErrorStateView(
            message: safetyFailureMessage(failure),
            onRetry: context.read<BlockedUsersCubit>().load,
          ),
          BlockedUsersStateLoaded(:final data) when data.items.isEmpty =>
            const EmptyStateView(
              icon: Icons.block,
              title: "You haven't blocked anyone",
              message:
                  'Blocked people can’t see your profile, call or message you.',
            ),
          final BlockedUsersStateLoaded s => _list(context, s),
        },
      ),
    );
  }

  Widget _list(BuildContext context, BlockedUsersStateLoaded s) {
    final theme = Theme.of(context);
    final items = s.data.items;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) {
          context.read<BlockedUsersCubit>().loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space4),
        itemCount: items.length + 1 + (s.data.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: DashuriTokens.space4),
                child: Text(
                  "Blocked people can't see your profile, call or message "
                  "you. They aren't notified.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          if (i > items.length) {
            return const Padding(
              padding: EdgeInsets.all(DashuriTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final u = items[i - 1];
          final busy = s.unblocking.contains(u.userId);
          return ResponsiveCenter(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.33, 0.33, 0.33, 0, 0, //
                  0.33, 0.33, 0.33, 0, 0, //
                  0.33, 0.33, 0.33, 0, 0, //
                  0, 0, 0, 1, 0, //
                ]),
                child: UserAvatar(name: u.displayName),
              ),
              title: Text(u.displayName, overflow: TextOverflow.ellipsis),
              subtitle: Text(blockedOn(u.blockedAt)),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 40),
                ),
                onPressed: busy ? null : () => _confirmUnblock(context, u),
                child: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Unblock',
                        semanticsLabel: 'Unblock ${u.displayName}',
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
