import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/city.dart';
import '../domain/usecases/location_usecases.dart';

/// City picker: search the curated list, or detect once from the device.
/// The picked city is saved to the profile before the page closes.
class CityPickerCubit extends Cubit<CityPickerState> {
  CityPickerCubit(
    this._search,
    this._detect,
    this._save,
    this._openSettings, {
    this.debounce = const Duration(milliseconds: 300),
  }) : super(const CityPickerState());

  final SearchCities _search;
  final DetectMyCity _detect;
  final SaveMyCity _save;
  final OpenLocationSettings _openSettings;
  final Duration debounce;
  Timer? _debounceTimer;
  int _searchSeq = 0;

  Future<void> load() => _runSearch('');

  void queryChanged(String query) {
    emit(state.copyWith(query: query));
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _runSearch(query.trim()));
  }

  Future<void> retry() => _runSearch(state.query.trim());

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    emit(state.copyWith(listStatus: CityListStatus.loading));
    final result = await _search(query);
    if (isClosed || seq != _searchSeq) return;
    emit(switch (result) {
      Success(:final value) => state.copyWith(
        listStatus: CityListStatus.loaded,
        cities: value,
      ),
      Err(:final failure) => state.copyWith(
        listStatus: CityListStatus.failed,
        listFailure: failure,
      ),
    });
  }

  /// "Use my location".
  Future<void> useMyLocation() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true, clearDetect: true));
    final result = await _detect(const NoInput());
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(state.copyWith(locating: false, detected: value));
        await select(value);
      case Err(:final failure):
        emit(state.copyWith(locating: false, detectFailure: failure));
    }
  }

  Future<void> openSettings() async {
    await _openSettings(const NoInput());
  }

  Future<void> select(City city) async {
    if (state.saving != null) return;
    emit(state.copyWith(saving: city, clearSaveFailure: true));
    final result = await _save(city.id);
    if (isClosed) return;
    emit(switch (result) {
      Success() => state.copyWith(saved: city, clearSaving: true),
      Err(:final failure) => state.copyWith(
        saveFailure: failure,
        clearSaving: true,
      ),
    });
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}

enum CityListStatus { loading, loaded, failed }

final class CityPickerState extends Equatable {
  const CityPickerState({
    this.query = '',
    this.listStatus = CityListStatus.loading,
    this.cities = const [],
    this.listFailure,
    this.locating = false,
    this.detected,
    this.detectFailure,
    this.saving,
    this.saved,
    this.saveFailure,
  });

  final String query;
  final CityListStatus listStatus;
  final List<City> cities;
  final Failure? listFailure;
  final bool locating;
  final City? detected;

  /// Why "Use my location" failed (permission, services, no nearby city).
  final Failure? detectFailure;

  /// City being saved.
  final City? saving;

  /// Saved city: the page closes with it.
  final City? saved;
  final Failure? saveFailure;

  CityPickerState copyWith({
    String? query,
    CityListStatus? listStatus,
    List<City>? cities,
    Failure? listFailure,
    bool? locating,
    City? detected,
    Failure? detectFailure,
    City? saving,
    City? saved,
    Failure? saveFailure,
    bool clearDetect = false,
    bool clearSaving = false,
    bool clearSaveFailure = false,
  }) => CityPickerState(
    query: query ?? this.query,
    listStatus: listStatus ?? this.listStatus,
    cities: cities ?? this.cities,
    listFailure: listFailure ?? this.listFailure,
    locating: locating ?? this.locating,
    detected: clearDetect ? null : (detected ?? this.detected),
    detectFailure: clearDetect ? null : (detectFailure ?? this.detectFailure),
    saving: clearSaving ? null : (saving ?? this.saving),
    saved: saved ?? this.saved,
    saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
  );

  @override
  List<Object?> get props => [
    query,
    listStatus,
    cities,
    listFailure,
    locating,
    detected,
    detectFailure,
    saving,
    saved,
    saveFailure,
  ];
}
