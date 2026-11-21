import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_card.dart';
import '../domain/usecases/list_available_hosts.dart';

part 'discovery_state.dart';

/// Loads `Page<HostCard>` for the page. Add one method per user action; each calls
/// a use case and emits states. No API or Supabase access here.
final class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit(this._listAvailableHosts)
    : super(const DiscoveryStateInitial());

  final ListAvailableHosts _listAvailableHosts;

  Future<void> load() async {
    emit(const DiscoveryStateLoading());
    final result = await _listAvailableHosts(const PageRequest());
    emit(switch (result) {
      Success(:final value) => DiscoveryStateLoaded(value),
      Err(:final failure) => DiscoveryStateFailed(failure),
    });
  }
}
