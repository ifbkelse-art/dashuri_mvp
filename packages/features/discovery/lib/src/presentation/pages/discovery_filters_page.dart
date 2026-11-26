import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/discovery_filter.dart';
import '../widgets/discovery_widgets.dart';

/// C03 filters. Pops the chosen [DiscoveryFilter]; the grid re-queries.
/// The API filters by one language, a city, Verified Host status and a sort
/// order (contract 2.3; verification 2026-11-23).
class DiscoveryFiltersPage extends StatefulWidget {
  const DiscoveryFiltersPage({
    super.key,
    this.initial = const DiscoveryFilter(),
  });

  final DiscoveryFilter initial;

  @override
  State<DiscoveryFiltersPage> createState() => _DiscoveryFiltersPageState();
}

class _DiscoveryFiltersPageState extends State<DiscoveryFiltersPage> {
  late DiscoveryFilter _f = widget.initial;

  Future<void> _pickCity() async {
    final result = await context.push<Object?>(RoutePaths.cityPicker);
    final city = cityFromPickerResult(result);
    if (city != null && mounted) {
      setState(() => _f = _f.copyWith(city: () => city));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _f = const DiscoveryFilter()),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: DashuriTokens.space4,
                ),
                child: ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Language', style: theme.textTheme.titleLarge),
                      const SizedBox(height: DashuriTokens.space3),
                      Wrap(
                        spacing: DashuriTokens.space2,
                        runSpacing: DashuriTokens.space2,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: _f.language == null,
                            onSelected: (_) => setState(
                              () => _f = _f.copyWith(language: () => null),
                            ),
                          ),
                          for (final MapEntry(:key, :value)
                              in discoveryLanguages.entries)
                            ChoiceChip(
                              label: Text(value),
                              selected: _f.language == key,
                              onSelected: (_) => setState(
                                () => _f = _f.copyWith(language: () => key),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DashuriTokens.space6),
                      Text('City', style: theme.textTheme.titleLarge),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(_f.city?.name ?? 'Any city'),
                        subtitle: _f.city?.state == null
                            ? null
                            : Text(_f.city!.state!),
                        trailing: _f.city == null
                            ? const Icon(Icons.chevron_right_rounded)
                            : IconButton(
                                tooltip: 'Clear city',
                                onPressed: () => setState(
                                  () => _f = _f.copyWith(city: () => null),
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                        onTap: _pickCity,
                      ),
                      const SizedBox(height: DashuriTokens.space6),
                      Text('Hosts', style: theme.textTheme.titleLarge),
                      const SizedBox(height: DashuriTokens.space3),
                      Wrap(
                        spacing: DashuriTokens.space2,
                        runSpacing: DashuriTokens.space2,
                        children: [
                          for (final v in DiscoveryVerification.values)
                            ChoiceChip(
                              avatar: v == DiscoveryVerification.verified
                                  ? const Icon(VerifiedHostBadge.icon, size: 18)
                                  : null,
                              label: Text(v.label),
                              selected: _f.verification == v,
                              onSelected: (_) => setState(
                                () => _f = _f.copyWith(verification: v),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: DashuriTokens.space6),
                      Text('Sort by', style: theme.textTheme.titleLarge),
                      for (final s in DiscoverySort.values)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.label),
                          selected: _f.sort == s,
                          trailing: _f.sort == s
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () =>
                              setState(() => _f = _f.copyWith(sort: s)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ResponsiveCenter(
              padding: EdgeInsets.all(context.pageGutter),
              child: PrimaryButton(
                label: 'Show hosts',
                onPressed: () => context.pop(_f),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
