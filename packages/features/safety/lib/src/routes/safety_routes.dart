import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/age_gate_cubit.dart';
import '../application/block_cubit.dart';
import '../application/blocked_users_cubit.dart';
import '../application/enforcement_cubit.dart';
import '../application/report_cubit.dart';
import '../domain/usecases/block_user.dart';
import '../domain/usecases/report_user.dart';
import '../presentation/pages/age_gate_page.dart';
import '../presentation/pages/block_confirm_page.dart';
import '../presentation/pages/blocked_users_page.dart';
import '../presentation/pages/enforcement_page.dart';
import '../presentation/pages/report_page.dart';

/// Safety routes.
///
/// Cross-feature contract for report and block (other features navigate by
/// constant only):
/// - Report (V11/V12): `context.push<bool>('${RoutePaths.report}?userId=<id>&name=<name>[&callId=<id>]')`.
///   Resolves `true` when a report was submitted.
/// - Block (V13): `context.push<bool>('${RoutePaths.report}?mode=block&userId=<id>&name=<name>')`.
///   Shown as a dialog over the current screen; resolves `true` once blocked.
final class SafetyRoutes implements FeatureRoutes {
  const SafetyRoutes();

  /// Builds the report/block location (for features that prefer a helper
  /// over string building; they still only depend on the path string).
  static String reportLocation({
    required String userId,
    required String name,
    String? callId,
    bool block = false,
  }) => Uri(
    path: RoutePaths.report,
    queryParameters: {
      if (block) 'mode': 'block',
      'userId': userId,
      'name': name,
      'callId': ?callId,
    },
  ).toString();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.ageGate,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<AgeGateCubit>(),
        child: const AgeGatePage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.report,
      pageBuilder: (context, state) {
        final q = state.uri.queryParameters;
        final userId = q['userId'];
        final name = (q['name'] ?? '').trim().isEmpty
            ? 'this person'
            : q['name']!;
        if (userId == null || userId.isEmpty) {
          return MaterialPage<bool>(
            key: state.pageKey,
            child: Scaffold(
              appBar: AppBar(),
              body: const ErrorStateView(
                title: 'Nothing to report',
                message:
                    'This link is missing who to report. Go back and '
                    'try again from their profile, chat or call.',
              ),
            ),
          );
        }
        if (q['mode'] == 'block') {
          return CustomTransitionPage<bool>(
            key: state.pageKey,
            opaque: false,
            barrierDismissible: true,
            barrierLabel: 'Cancel',
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
            child: BlocProvider(
              create: (_) =>
                  BlockCubit(GetIt.instance<BlockUser>(), userId: userId),
              child: BlockConfirmPage(name: name),
            ),
          );
        }
        final callId = q['callId'];
        return MaterialPage<bool>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: BlocProvider(
            create: (_) => ReportCubit(
              GetIt.instance<ReportUser>(),
              GetIt.instance<BlockUser>(),
              targetUserId: userId,
              callId: (callId?.isEmpty ?? true) ? null : callId,
            ),
            child: ReportPage(
              name: name,
              fromCall: callId != null && callId.isNotEmpty,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.blockedUsers,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<BlockedUsersCubit>()..load(),
        child: const BlockedUsersPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.enforcement,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<EnforcementCubit>()..load(),
        child: const EnforcementPage(),
      ),
    ),
  ];
}
