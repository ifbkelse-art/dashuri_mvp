import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/account_status.dart';
import '../domain/usecases/accept_community_rules.dart';

/// A13: one explicit "I agree" action.
final class CommunityRulesCubit extends Cubit<CommunityRulesState> {
  CommunityRulesCubit(this._accept) : super(const CommunityRulesState());

  final AcceptCommunityRules _accept;

  Future<void> accept() async {
    if (state.submitting) return;
    emit(const CommunityRulesState(submitting: true));
    final result = await _accept(const NoInput());
    emit(switch (result) {
      Success(:final value) => CommunityRulesState(accepted: value),
      Err(:final failure) => CommunityRulesState(failure: failure),
    });
  }
}

final class CommunityRulesState extends Equatable {
  const CommunityRulesState({
    this.submitting = false,
    this.accepted,
    this.failure,
  });

  final bool submitting;

  /// Account status returned by the server after acceptance.
  final AccountStatus? accepted;
  final Failure? failure;

  @override
  List<Object?> get props => [submitting, accepted, failure];
}
