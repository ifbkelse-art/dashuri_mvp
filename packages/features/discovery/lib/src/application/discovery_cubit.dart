import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/discovery_filter.dart';
import '../domain/entities/host_card.dart';
import '../domain/usecases/list_available_hosts.dart';

part 'discovery_state.dart';

/// The C01 host grid: filters, sort, cursor paging and pull to refresh.
// Not final: page tests mock it.
class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._listAvailableHosts, {this.pageSize = 20})
    : super(const DiscoveryStateInitial());

  final ListAvailableHosts _listAvailableHosts;
  final int pageSize;

  /// Increments per new query so late responses for an old filter are dropped.
  int _generation = 0;

  Future<void> load({DiscoveryFilter? filter}) async {
    final f = filter ?? state.filter;
    final gen = ++_generation;
    emit(DiscoveryStateLoading(f));
    final result = await _listAvailableHosts((
      page: PageRequest(limit: pageSize),
      filter: f,
    ));
    if (gen != _generation) return;
    emit(switch (result) {
      Success(:final value) => DiscoveryStateLoaded(value, f),
      Err(:final failure) => DiscoveryStateFailed(failure, f),
    });
  }

  /// Pull to refresh: keeps the grid visible while re-fetching page one.
  Future<void> refresh() async {
    final s = state;
    if (s is! DiscoveryStateLoaded) return load();
    final gen = ++_generation;
    final result = await _listAvailableHosts((
      page: PageRequest(limit: pageSize),
      filter: s.filter,
    ));
    if (gen != _generation) return;
    emit(switch (result) {
      Success(:final value) => DiscoveryStateLoaded(value, s.filter),
      Err(:final failure) => DiscoveryStateFailed(failure, s.filter),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! DiscoveryStateLoaded || !s.data.hasMore || s.loadingMore) {
      return;
    }
    final gen = _generation;
    emit(DiscoveryStateLoaded(s.data, s.filter, true));
    final result = await _listAvailableHosts((
      page: PageRequest(cursor: s.data.nextCursor, limit: pageSize),
      filter: s.filter,
    ));
    if (gen != _generation) return;
    emit(switch (result) {
      Success(:final value) => DiscoveryStateLoaded(
        Page(
          items: [...s.data.items, ...value.items],
          nextCursor: value.nextCursor,
        ),
        s.filter,
      ),
      Err() => DiscoveryStateLoaded(s.data, s.filter, false, true),
    });
  }

  Future<void> applyFilter(DiscoveryFilter filter) => load(filter: filter);

  /// Language chip; null = "All".
  Future<void> setLanguage(String? code) =>
      load(filter: state.filter.copyWith(language: () => code));

  Future<void> setSort(DiscoverySort sort) =>
      load(filter: state.filter.copyWith(sort: sort));

  Future<void> clearFilters() =>
      load(filter: DiscoveryFilter(sort: state.filter.sort));
}
