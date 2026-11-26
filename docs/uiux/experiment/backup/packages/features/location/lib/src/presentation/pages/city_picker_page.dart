import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/city_picker_cubit.dart';
import '../../domain/entities/city.dart';

/// Coarse city picker (decision F4) at `RoutePaths.cityPicker`. Pops with
/// the saved [City]. Coordinates are never stored.
class CityPickerPage extends StatelessWidget {
  const CityPickerPage({super.key});

  static String detectMessage(Failure f) => switch (f) {
    PlatformFailure(code: 'location_permission_denied') =>
      'Location permission was not given. You can search for your city '
          'instead.',
    PlatformFailure(code: 'location_permission_permanently_denied') =>
      'Location access is off for Dashuri. Turn it on in settings, or search '
          'for your city.',
    PlatformFailure(code: 'location_services_disabled') =>
      'Location services are off on this phone. Turn them on, or search for '
          'your city.',
    PlatformFailure(code: 'location_unavailable') =>
      "We couldn't get your location. Search for your city instead.",
    NotFoundFailure() ||
    BusinessRuleFailure(code: 'no_supported_city_nearby') =>
      "Dashuri isn't available near you yet. Pick the nearest city from the "
          'list.',
    _ => failureMessage(f),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<CityPickerCubit, CityPickerState>(
      listenWhen: (a, b) =>
          (b.saved != null && a.saved != b.saved) ||
          (b.saveFailure != null && a.saveFailure != b.saveFailure),
      listener: (context, state) {
        if (state.saveFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failureMessage(state.saveFailure!))),
          );
          return;
        }
        if (context.canPop()) context.pop(state.saved);
      },
      builder: (context, state) {
        final cubit = context.read<CityPickerCubit>();
        final permanentlyDenied =
            state.detectFailure is PlatformFailure &&
            (state.detectFailure!.code ==
                    'location_permission_permanently_denied' ||
                state.detectFailure!.code == 'location_services_disabled');
        return Scaffold(
          appBar: AppBar(title: const Text('Your city')),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: DashuriTokens.space2),
                      Text(
                        'Shown on your profile as a city only. We never store '
                        'your exact location.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: DashuriTokens.space4),
                      TextField(
                        onChanged: cubit.queryChanged,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search cities',
                          labelText: 'Search cities',
                        ),
                      ),
                      const SizedBox(height: DashuriTokens.space3),
                      OutlinedButton.icon(
                        onPressed: state.locating || state.saving != null
                            ? null
                            : cubit.useMyLocation,
                        icon: state.locating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          state.locating
                              ? 'Finding your city…'
                              : 'Use my location',
                        ),
                      ),
                      if (state.detectFailure != null) ...[
                        const SizedBox(height: DashuriTokens.space3),
                        InfoBanner(
                          tone: InfoBannerTone.warning,
                          icon: Icons.location_off_outlined,
                          message: detectMessage(state.detectFailure!),
                        ),
                        if (permanentlyDenied)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: cubit.openSettings,
                              child: const Text('Open settings'),
                            ),
                          ),
                      ],
                      const SizedBox(height: DashuriTokens.space3),
                    ],
                  ),
                ),
                Expanded(child: _results(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _results(BuildContext context, CityPickerState state) {
    final cubit = context.read<CityPickerCubit>();
    return switch (state.listStatus) {
      CityListStatus.loading => const LoadingView(),
      CityListStatus.failed => ErrorStateView(
        message: failureMessage(state.listFailure!),
        onRetry: cubit.retry,
      ),
      CityListStatus.loaded when state.cities.isEmpty => EmptyStateView(
        icon: Icons.location_city_outlined,
        title: 'No matching cities',
        message: state.query.trim().isEmpty
            ? 'No cities are available yet.'
            : 'Dashuri is available in selected Indian cities. Try another '
                  'spelling or a nearby city.',
      ),
      CityListStatus.loaded => ListView.builder(
        itemCount: state.cities.length,
        itemBuilder: (context, i) {
          final city = state.cities[i];
          final saving = state.saving == city;
          return ResponsiveCenter(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_city_outlined),
              title: Text(city.name),
              subtitle: city.state.isEmpty ? null : Text(city.state),
              trailing: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: state.saving == null ? () => cubit.select(city) : null,
            ),
          );
        },
      ),
    };
  }
}
