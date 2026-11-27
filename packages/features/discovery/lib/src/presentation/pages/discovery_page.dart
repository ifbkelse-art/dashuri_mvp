import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/discovery_cubit.dart';
import '../../application/discovery_header_cubit.dart';
import '../../domain/entities/discovery_filter.dart';
import '../widgets/discovery_widgets.dart';

/// C01–C06 home: header, Free Call Card (C02), language chips, online count,
/// sort, and the responsive host grid with paging and pull to refresh.
class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key, this.now});

  /// For tests: the time used for the greeting.
  final DateTime? now;

  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<DiscoveryCubit>();
    final result = await context.push<DiscoveryFilter>(
      RoutePaths.discoveryFilters,
      extra: cubit.state.filter,
    );
    if (result != null) await cubit.applyFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscoveryCubit>();
    final header = context.read<DiscoveryHeaderCubit>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, c) {
            final gutter = context.pageGutter;
            final contentWidth =
                (c.maxWidth.clamp(0, DashuriTokens.maxWideContentWidth) -
                        gutter * 2)
                    .toDouble();
            final side = ((c.maxWidth - contentWidth) / 2).clamp(
              gutter,
              double.infinity,
            );
            final pad = EdgeInsets.symmetric(horizontal: side);
            return RefreshIndicator(
              onRefresh: () => Future.wait([cubit.refresh(), header.load()]),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 600) unawaited(cubit.loadMore());
                  return false;
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: pad,
                      sliver: SliverToBoxAdapter(
                        child: _Header(
                          now: now,
                          onFilters: () => _openFilters(context),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: pad.copyWith(bottom: DashuriTokens.space8),
                      sliver: _Grid(
                        columns: context.gridColumns(
                          contentWidth,
                          minTileWidth: 168,
                          max: 5,
                        ),
                        onFilters: () => _openFilters(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _greeting(DateTime now) {
  final h = now.hour;
  return h < 12
      ? 'Good morning'
      : h < 17
      ? 'Good afternoon'
      : 'Good evening';
}

class _Header extends StatelessWidget {
  const _Header({required this.onFilters, this.now});

  final VoidCallback onFilters;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = context.watch<DiscoveryHeaderCubit>().state;
    final filter = context.select<DiscoveryCubit, DiscoveryFilter>(
      (c) => c.state.filter,
    );
    final cubit = context.read<DiscoveryCubit>();
    final name = h.home.displayName;
    final greeting = _greeting(now ?? DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DashuriTokens.space4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Dashuri',
                style: theme.textTheme.displaySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            BalancePill(
              diamonds: h.home.availableDiamonds,
              onTap: () => context.push(RoutePaths.buyDiamonds),
            ),
            const SizedBox(width: DashuriTokens.space2),
            IconButton.outlined(
              tooltip: 'Notifications',
              onPressed: () => context.push(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space5),
        Text(
          name == null || name.isEmpty ? greeting : '$greeting, $name',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'Who would you like to talk to?',
          style: theme.textTheme.headlineMedium,
        ),
        if (h.showFreeCall) ...[
          const SizedBox(height: DashuriTokens.space5),
          _FreeCallBanner(
            onStart: () => context.push(RoutePaths.freeCall),
            onDismiss: context.read<DiscoveryHeaderCubit>().dismissFreeCall,
          ),
        ],
        const SizedBox(height: DashuriTokens.space5),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // The filter-count badge sits above the button; the default clip
          // would cut it in half.
          clipBehavior: Clip.none,
          child: Row(
            children: [
              Badge.count(
                count: filter.activeCount,
                isLabelVisible: filter.activeCount > 0,
                child: IconButton.outlined(
                  tooltip: 'Filters',
                  onPressed: onFilters,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
              const SizedBox(width: DashuriTokens.space2),
              _LangChip(
                label: 'All',
                selected: filter.language == null,
                onTap: () => cubit.setLanguage(null),
              ),
              for (final MapEntry(:key, :value) in discoveryLanguages.entries)
                _LangChip(
                  label: value,
                  selected: filter.language == key,
                  onTap: () => cubit.setLanguage(key),
                ),
            ],
          ),
        ),
        const SizedBox(height: DashuriTokens.space4),
        Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: DashuriColors.of(context).onlineDot,
            ),
            const SizedBox(width: DashuriTokens.space2),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Online now',
                  children: [
                    if (h.home.onlineCount != null)
                      TextSpan(
                        text: ' · ${DashuriFormat.count(h.home.onlineCount!)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // At the end of the row with its natural width, capped so a long
            // label at large text truncates instead of overflowing.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .45,
              ),
              child: PopupMenuButton<DiscoverySort>(
                tooltip: 'Sort',
                initialValue: filter.sort,
                onSelected: cubit.setSort,
                itemBuilder: (_) => [
                  for (final s in DiscoverySort.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: DashuriTokens.space2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          filter.sort == DiscoverySort.recommended
                              ? 'Recommended'
                              : filter.sort.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space3),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: DashuriTokens.space2),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
}

class _FreeCallBanner extends StatelessWidget {
  const _FreeCallBanner({required this.onStart, required this.onDismiss});

  final VoidCallback onStart;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DashuriTokens.burgundy700, DashuriTokens.burgundy950],
        ),
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashuriTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: DashuriTokens.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Welcome gift',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: DashuriTokens.gold100,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            Text(
              'Your first minute is on us',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: DashuriTokens.space2),
            Text(
              "Get matched with a host who's online now for a free one-minute "
              'video call.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: DashuriTokens.space4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: DashuriTokens.burgundy800,
              ),
              onPressed: onStart,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Start free call'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.onFilters});

  final int columns;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscoveryCubit>();
    final s = context.watch<DiscoveryCubit>().state;
    final online = context.select<DiscoveryHeaderCubit, int?>(
      (c) => c.state.home.onlineCount,
    );
    final delegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: DashuriTokens.space3,
      crossAxisSpacing: DashuriTokens.space3,
      childAspectRatio: .72,
    );
    switch (s) {
      case DiscoveryStateInitial() || DiscoveryStateLoading():
        return SliverGrid(
          gridDelegate: delegate,
          delegate: SliverChildBuilderDelegate(
            (_, _) => const HostCardSkeleton(),
            childCount: columns * 3,
          ),
        );
      case DiscoveryStateFailed(:final failure):
        return SliverToBoxAdapter(
          child: ErrorStateView(
            title: "Couldn't load hosts",
            message: discoveryFailureMessage(failure),
            onRetry: cubit.load,
          ),
        );
      case DiscoveryStateLoaded(:final data, :final filter)
          when data.items.isEmpty:
        return SliverToBoxAdapter(
          child: filter.hasFilters
              ? _NoFilterResults(
                  filter: filter,
                  online: online,
                  onClear: cubit.clearFilters,
                )
              : EmptyStateView(
                  icon: Icons.nightlight_round,
                  title: "It's quiet right now",
                  message:
                      'No hosts are online at the moment. Hosts go online '
                      'whenever they like. Pull down or refresh to check again.',
                  actionLabel: 'Refresh',
                  onAction: cubit.refresh,
                ),
        );
      case DiscoveryStateLoaded(:final data):
        return SliverMainAxisGroup(
          slivers: [
            SliverGrid(
              gridDelegate: delegate,
              delegate: SliverChildBuilderDelegate((context, i) {
                final host = data.items[i];
                return HostGridCard(
                  host: host,
                  onTap: () => context.push(
                    RoutePaths.withParams(RoutePaths.hostProfile, {
                      'userId': host.userId,
                    }),
                  ),
                );
              }, childCount: data.items.length),
            ),
            if (data.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(DashuriTokens.space5),
                  child: Center(
                    child: s.loadMoreFailed
                        ? TextButton(
                            onPressed: cubit.loadMore,
                            child: const Text('Load more hosts'),
                          )
                        : const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                  ),
                ),
              ),
          ],
        );
    }
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults({
    required this.filter,
    required this.online,
    required this.onClear,
  });

  final DiscoveryFilter filter;
  final int? online;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscoveryCubit>();
    return Column(
      children: [
        Wrap(
          spacing: DashuriTokens.space2,
          runSpacing: DashuriTokens.space2,
          children: [
            if (filter.language != null)
              InputChip(
                label: Text(languageName(filter.language!)),
                onDeleted: () => cubit.setLanguage(null),
                deleteButtonTooltipMessage: 'Remove language filter',
              ),
            if (filter.city != null)
              InputChip(
                label: Text(filter.city!.name),
                onDeleted: () =>
                    cubit.applyFilter(filter.copyWith(city: () => null)),
                deleteButtonTooltipMessage: 'Remove city filter',
              ),
          ],
        ),
        EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'No hosts match',
          message: online == null
              ? 'Nobody online fits these filters right now.'
              : 'Nobody online fits these filters right now. '
                    '${DashuriFormat.count(online!)} other hosts are online.',
          actionLabel: 'Clear all filters',
          onAction: onClear,
        ),
      ],
    );
  }
}
