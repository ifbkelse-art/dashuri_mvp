import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/permissions_cubit.dart';
import '../../domain/entities/device_permission.dart';
import '../widgets/auth_scaffold.dart';

/// A14 permissions primer and A15 denied state ("Open settings").
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings page: re-read the permission states.
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionsCubit>().load();
    }
  }

  static const _rows = [
    (
      DevicePermission.camera,
      Icons.videocam_outlined,
      'Camera',
      'So the person you call can see you',
    ),
    (
      DevicePermission.microphone,
      Icons.mic_none_rounded,
      'Microphone',
      'So they can hear you',
    ),
    (
      DevicePermission.notifications,
      Icons.notifications_none_rounded,
      'Notifications',
      'Know when someone messages you',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<PermissionsCubit, PermissionsState>(
      builder: (context, state) {
        final cubit = context.read<PermissionsCubit>();
        final denied = state.states?.anyRequiredPermanentlyDenied ?? false;
        return AuthScaffold(
          step: 6,
          showBack: false,
          title: denied ? 'Camera access is off' : 'Ready for your first call',
          subtitle: denied
              ? 'To start a video call, allow Dashuri to use your camera and '
                    "microphone in your phone's settings."
              : 'Dashuri needs a few permissions so calls work smoothly.',
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (denied)
                PrimaryButton(
                  label: 'Open settings',
                  icon: Icons.settings_outlined,
                  onPressed: cubit.openSettings,
                )
              else
                PrimaryButton(
                  label: 'Allow access',
                  busy: state.busy,
                  onPressed: cubit.allow,
                ),
              const SizedBox(height: DashuriTokens.space2),
              TextButton(
                onPressed: state.busy ? null : cubit.skip,
                child: const Text('Not now'),
              ),
            ],
          ),
          children: [
            if (state.failure != null) ...[
              InfoBanner(
                tone: InfoBannerTone.error,
                message: failureMessage(state.failure!),
              ),
              const SizedBox(height: DashuriTokens.space4),
            ],
            Card(
              child: Column(
                children: [
                  for (final (perm, icon, title, why) in _rows)
                    ListTile(
                      leading: Icon(icon),
                      title: Text(title),
                      subtitle: Text(why),
                      trailing: _StatusLabel(
                        state: state.states?.of(perm),
                        optional: perm == DevicePermission.notifications,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DashuriTokens.space4),
            Text(
              'Camera and microphone are needed only for video calls. You can '
              'browse without them, and change this any time in your phone '
              'settings.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.state, required this.optional});

  final DevicePermissionState? state;
  final bool optional;

  @override
  Widget build(BuildContext context) => switch (state) {
    DevicePermissionState.granted => const StatusTag(
      label: 'Allowed',
      tone: StatusTone.success,
    ),
    DevicePermissionState.permanentlyDenied => const StatusTag(
      label: 'Denied',
      tone: StatusTone.error,
    ),
    _ =>
      optional
          ? const StatusTag(label: 'Optional', tone: StatusTone.neutral)
          : const StatusTag(label: 'Needed', tone: StatusTone.info),
  };
}
