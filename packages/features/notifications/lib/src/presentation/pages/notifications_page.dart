import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/inbox_cubit.dart';
import '../../domain/entities/inbox_item.dart';

/// C11 notifications inbox, grouped by day, unread items with a dot.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.now});

  /// "Today" reference (tests inject a fixed time).
  final DateTime? now;

  /// Where tapping a notification of [kind] leads (by route constant only).
  static String? destinationFor(String kind) {
    final k = kind.toLowerCase();
    if (k.startsWith('purchase') ||
        k.startsWith('wallet') ||
        k.startsWith('payment')) {
      return RoutePaths.transactions;
    }
    if (k.startsWith('chat') || k.startsWith('message')) {
      return RoutePaths.conversations;
    }
    if (k.startsWith('report') ||
        k.startsWith('enforcement') ||
        k.startsWith('appeal') ||
        k.startsWith('safety')) {
      return RoutePaths.enforcement;
    }
    if (k.startsWith('call')) return RoutePaths.callHistory;
    if (k.startsWith('host')) return RoutePaths.hostDashboard;
    return null;
  }

  static IconData iconFor(String kind) {
    final k = kind.toLowerCase();
    if (k.startsWith('purchase') || k.startsWith('wallet')) {
      return Icons.diamond_outlined;
    }
    if (k.startsWith('payment')) return Icons.receipt_long_outlined;
    if (k.startsWith('chat') || k.startsWith('message')) {
      return Icons.chat_bubble_outline;
    }
    if (k.startsWith('report') ||
        k.startsWith('safety') ||
        k.startsWith('enforcement') ||
        k.startsWith('appeal')) {
      return Icons.verified_user_outlined;
    }
    if (k.startsWith('call')) return Icons.videocam_outlined;
    return Icons.notifications_none_rounded;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dayLabel(DateTime d, DateTime today) {
    final day = DateTime(d.year, d.month, d.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]}${d.year == today.year ? '' : ' ${d.year}'}';
  }

  String _time(DateTime d, DateTime today) {
    final diff = today.difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24 && today.day == d.day) return '${diff.inHours}h';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InboxCubit, InboxState>(
      builder: (context, state) {
        final cubit = context.read<InboxCubit>();
        final unread = state is InboxStateLoaded ? state.unreadCount : 0;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (unread > 0)
                IconButton(
                  tooltip: 'Mark all as read',
                  icon: const Icon(Icons.done_all),
                  onPressed: cubit.markAllRead,
                ),
            ],
          ),
          body: switch (state) {
            InboxStateInitial() ||
            InboxStateLoading() => const SkeletonList(avatar: false),
            InboxStateFailed(:final failure) => ErrorStateView(
              title: "Couldn't load your notifications",
              message: failureMessage(failure),
              onRetry: cubit.load,
            ),
            InboxStateLoaded(:final data) when data.items.isEmpty =>
              RefreshIndicator(
                onRefresh: cubit.refresh,
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: c.maxHeight,
                      child: const EmptyStateView(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications yet',
                        message:
                            'Purchases, messages and safety updates will '
                            'show up here.',
                      ),
                    ),
                  ),
                ),
              ),
            final InboxStateLoaded s => _list(context, s),
          },
        );
      },
    );
  }

  Widget _list(BuildContext context, InboxStateLoaded s) {
    final today = (now ?? DateTime.now()).toLocal();
    final rows = <Widget>[];
    String? lastDay;
    for (final item in s.data.items) {
      final local = item.createdAt.toLocal();
      final day = _dayLabel(local, today);
      if (day != lastDay) {
        rows.add(_DayHeader(day));
        lastDay = day;
      }
      rows.add(_Row(item: item, time: _time(local, today)));
    }
    if (s.data.hasMore) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(DashuriTokens.space4),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: context.read<InboxCubit>().refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) {
            context.read<InboxCubit>().loadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: DashuriTokens.space6),
          itemCount: rows.length,
          itemBuilder: (context, i) =>
              ResponsiveCenter(maxWidth: 720, child: rows[i]),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DashuriTokens.space5, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.time});

  final InboxItem item;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = item.readAt == null;
    final destination = NotificationsPage.destinationFor(item.kind);
    return Semantics(
      label: unread ? 'Unread' : null,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () {
          context.read<InboxCubit>().markRead(item.id);
          if (destination != null) context.push(destination);
        },
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            NotificationsPage.iconFor(item.kind),
            color: theme.colorScheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: DashuriTokens.space2),
            Text(time, style: theme.textTheme.bodySmall),
          ],
        ),
        subtitle: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
