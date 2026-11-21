import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/city_picker_cubit.dart';
import '../presentation/pages/city_picker_page.dart';

/// `RoutePaths.cityPicker`: `final city = await context.push<Object?>(RoutePaths.cityPicker)`.
/// The city is already saved to the profile when the page pops.
final class LocationRoutes implements FeatureRoutes {
  const LocationRoutes();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.cityPicker,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<CityPickerCubit>()..load(),
        child: const CityPickerPage(),
      ),
    ),
  ];
}
