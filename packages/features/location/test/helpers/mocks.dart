import 'package:bloc_test/bloc_test.dart';
import 'package:feature_location/feature_location.dart';
import 'package:mocktail/mocktail.dart';

class MockSearchCities extends Mock implements SearchCities {}

class MockDetectMyCity extends Mock implements DetectMyCity {}

class MockSaveMyCity extends Mock implements SaveMyCity {}

class MockOpenLocationSettings extends Mock implements OpenLocationSettings {}

class MockLocationRepository extends Mock implements LocationRepository {}

class MockCityPickerCubit extends MockCubit<CityPickerState>
    implements CityPickerCubit {}

const pune = City(id: 'pune', name: 'Pune', state: 'Maharashtra');
const mumbai = City(id: 'mumbai', name: 'Mumbai', state: 'Maharashtra');
