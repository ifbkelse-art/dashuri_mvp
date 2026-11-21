import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/call_bloc.dart';
import '../../domain/entities/call_session.dart';
import '../video/video_view_factory.dart';
import '../widgets/call_widgets.dart';

/// The call screen for both sides: V02 ringing, V03 connecting, V04/V17
/// active, V05 low balance, V07 interrupted, V15 free minute and V16
/// incoming. Every billing figure shown comes from the server session.
class CallPage extends StatefulWidget {
  const CallPage({required this.views, super.key, this.manageSystemUi = true});

  final VideoViewFactory views;

  /// Full-screen (immersive) while the page is open.
  final bool manageSystemUi;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  int? _lowBalanceValue;
  DateTime? _lowBalanceAt;
  int _frozenElapsed = 0;

  @override
  void initState() {
    super.initState();
    if (widget.manageSystemUi) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  @override
  void dispose() {
    if (widget.manageSystemUi) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _onState(BuildContext context, CallState s) {
    if (s.lowBalanceSecondsRemaining != null &&
        s.lowBalanceSecondsRemaining != _lowBalanceValue) {
      _lowBalanceValue = s.lowBalanceSecondsRemaining;
      _lowBalanceAt = DateTime.now().toUtc();
    }
    if (s.status != CallUiStatus.ended) return;
    final session = s.session;
    final router = GoRouter.of(context);
    if (session == null) {
      router.go(
        s.requestedEndReason == 'declined'
            ? RoutePaths.hostDashboard
            : RoutePaths.discovery,
      );
      return;
    }
    final receiverNoCall =
        session.role == CallRole.receiver &&
        (session.phase == CallPhase.declined ||
            session.phase == CallPhase.missed ||
            s.requestedEndReason == 'declined');
    if (receiverNoCall) {
      router.go(RoutePaths.hostDashboard);
      return;
    }
    router.go(
      RoutePaths.withParams(RoutePaths.callSummary, {
        'callId': session.callId,
      }),
    );
    if (s.requestedEndReason == 'report') {
      unawaited(
        router.push(
          Uri(
            path: RoutePaths.report,
            queryParameters: {
              'userId': session.peerUserId,
              'callId': session.callId,
              if (session.peerName.isNotEmpty) 'name': session.peerName,
            },
          ).toString(),
        ),
      );
    }
  }

  Future<void> _confirmReport(BuildContext context, CallSession s) async {
    final bloc = context.read<CallBloc>();
    final name = s.peerName.isEmpty ? 'this person' : s.peerName;
    final ok = await showConfirmDialog(
      context,
      title: 'Report $name?',
      message:
          'Reporting ends the call immediately. You can then tell us what '
          'happened.',
      confirmLabel: 'End call and report',
      destructive: true,
    );
    if (ok) bloc.add(const CallEndRequested(reason: 'report'));
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bloc = context.read<CallBloc>();
    final ok = await showConfirmDialog(
      context,
      title: 'End this call?',
      message: 'The call ends for both of you.',
      confirmLabel: 'End call',
      destructive: true,
    );
    if (ok) bloc.add(const CallEndRequested());
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: DashuriTheme.dark(),
    child: BlocConsumer<CallBloc, CallState>(
      listener: _onState,
      builder: (context, s) => PopScope(
        canPop:
            s.status == CallUiStatus.failed ||
            s.status == CallUiStatus.ended ||
            s.status == CallUiStatus.idle,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmLeave(context));
        },
        child: Scaffold(
          backgroundColor: DashuriTokens.neutral950,
          body: _body(context, s),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context, CallState s) {
    final session = s.session;
    switch (s.status) {
      case CallUiStatus.idle || CallUiStatus.requesting:
        return const LoadingView(message: 'Opening call…');
      case CallUiStatus.failed:
        return SafeArea(
          child: ErrorStateView(
            title: "The call couldn't continue",
            message: s.failure == null
                ? 'Something went wrong. Please try again.'
                : callFailureMessage(s.failure!),
            onRetry: null,
          ),
        ).withAction(
          label: session == null ? 'Close' : 'End call',
          onPressed: () => session == null
              ? context.go(RoutePaths.discovery)
              : context.read<CallBloc>().add(const CallEndRequested()),
        );
      case CallUiStatus.ending || CallUiStatus.ended:
        return const LoadingView(message: 'Ending call…');
      case CallUiStatus.incoming:
        return session == null
            ? const LoadingView(message: 'Incoming call…')
            : _IncomingView(session: session);
      case CallUiStatus.ringing || CallUiStatus.connecting:
      case CallUiStatus.active || CallUiStatus.paused:
        if (session == null) return const LoadingView();
        return _CallCanvas(
          state: s,
          session: session,
          views: widget.views,
          lowBalanceAt: _lowBalanceAt,
          frozenElapsed: _frozenElapsed,
          onElapsed: (v) => _frozenElapsed = v,
          onReport: () => unawaited(_confirmReport(context, session)),
        );
    }
  }
}

extension on Widget {
  Widget withAction({required String label, required VoidCallback onPressed}) =>
      Column(
        children: [
          Expanded(child: this),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(DashuriTokens.space5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: PrimaryButton(label: label, onPressed: onPressed),
              ),
            ),
          ),
        ],
      );
}

class _IncomingView extends StatelessWidget {
  const _IncomingView({required this.session});

  final CallSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CallBloc>();
    final name = session.peerName.isEmpty ? 'A customer' : session.peerName;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: EdgeInsets.all(context.pageGutter),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Incoming video call',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space8),
                  Column(
                    children: [
                      UserAvatar(
                        name: name,
                        url: session.peer?.photoUrl,
                        radius: (c.maxHeight * .1).clamp(40.0, 64.0),
                      ),
                      const SizedBox(height: DashuriTokens.space5),
                      Text(
                        name,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DashuriTokens.space3),
                      GlassPill(
                        child: CurrencyAmount.diamonds(
                          session.ratePerMinute,
                          suffix: ' / min',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (session.isFreeCall) ...[
                        const SizedBox(height: DashuriTokens.space2),
                        const GlassPill(child: Text('Free Call Card minute')),
                      ],
                    ],
                  ),
                  const SizedBox(height: DashuriTokens.space8),
                  Wrap(
                    spacing: DashuriTokens.space10,
                    runSpacing: DashuriTokens.space4,
                    alignment: WrapAlignment.center,
                    children: [
                      _Labeled(
                        label: 'Decline',
                        child: RoundControl(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          destructive: true,
                          size: 72,
                          onPressed: () =>
                              bloc.add(CallIncomingDeclined(session.callId)),
                        ),
                      ),
                      _Labeled(
                        label: 'Accept',
                        child: Material(
                          color: DashuriTokens.success,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                bloc.add(CallIncomingAccepted(session.callId)),
                            child: const SizedBox.square(
                              dimension: 72,
                              child: Icon(
                                Icons.videocam_rounded,
                                color: Colors.white,
                                size: 32,
                                semanticLabel: 'Accept',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DashuriTokens.space4),
                  Text(
                    'You can decline any call. There is no penalty.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      const SizedBox(height: DashuriTokens.space2),
      Text(label, style: const TextStyle(color: Colors.white)),
    ],
  );
}

class _CallCanvas extends StatelessWidget {
  const _CallCanvas({
    required this.state,
    required this.session,
    required this.views,
    required this.lowBalanceAt,
    required this.frozenElapsed,
    required this.onElapsed,
    required this.onReport,
  });

  final CallState state;
  final CallSession session;
  final VideoViewFactory views;
  final DateTime? lowBalanceAt;
  final int frozenElapsed;
  final ValueChanged<int> onElapsed;
  final VoidCallback onReport;

  bool get _live =>
      state.status == CallUiStatus.active || state.status == CallUiStatus.paused;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CallBloc>();
    final peerName = session.peerName.isEmpty
        ? (session.role == CallRole.caller ? 'Host' : 'Customer')
        : session.peerName;
    final avatar = Center(
      child: UserAvatar(name: peerName, url: session.peer?.photoUrl, radius: 56),
    );
    final isWaiting = !_live;
    return LayoutBuilder(
      builder: (context, c) {
        final area = c.biggest;
        final padding = MediaQuery.paddingOf(context);
        return Stack(
          children: [
            Positioned.fill(
              child: isWaiting && state.status == CallUiStatus.ringing
                  ? const ColoredBox(color: DashuriTokens.burgundy950)
                  : views.remoteVideo(
                      placeholder: ColoredBox(
                        color: DashuriTokens.neutral900,
                        child: avatar,
                      ),
                    ),
            ),
            if (isWaiting)
              Positioned.fill(
                child: _WaitingOverlay(state: state, session: session),
              ),
            if (_live && state.mediaJoined)
              DraggableCornerTile(
                areaSize: area,
                topInset: padding.top + 120,
                bottomInset: padding.bottom + 110,
                child: state.cameraOn
                    ? views.localPreview(
                        placeholder: const ColoredBox(
                          color: DashuriTokens.neutral800,
                        ),
                      )
                    : const ColoredBox(
                        color: DashuriTokens.neutral800,
                        child: Center(
                          child: Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(DashuriTokens.space4),
                  child: _TopBar(
                    state: state,
                    session: session,
                    peerName: peerName,
                    lowBalanceAt: lowBalanceAt,
                    frozenElapsed: frozenElapsed,
                    onElapsed: onElapsed,
                  ),
                ),
              ),
            ),
            if (_live && state.reconnecting)
              const Positioned.fill(child: _ReconnectingOverlay()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(DashuriTokens.space4),
                  child: CallControlsBar(
                    children: [
                      RoundControl(
                        icon: state.microphoneOn
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        label: state.microphoneOn
                            ? 'Mute microphone'
                            : 'Unmute microphone',
                        active: !state.microphoneOn,
                        onPressed: state.mediaJoined
                            ? () => bloc.add(const CallMicrophoneToggled())
                            : null,
                      ),
                      RoundControl(
                        icon: state.cameraOn
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: state.cameraOn
                            ? 'Turn camera off'
                            : 'Turn camera on',
                        active: !state.cameraOn,
                        onPressed: state.mediaJoined
                            ? () => bloc.add(const CallCameraToggled())
                            : null,
                      ),
                      RoundControl(
                        icon: Icons.cameraswitch_rounded,
                        label: 'Flip camera',
                        onPressed: state.mediaJoined
                            ? () => bloc.add(const CallCameraFlipped())
                            : null,
                      ),
                      RoundControl(
                        icon: Icons.flag_rounded,
                        label: 'Report',
                        onPressed: onReport,
                      ),
                      RoundControl(
                        icon: Icons.call_end_rounded,
                        label: state.status == CallUiStatus.ringing
                            ? 'Cancel call'
                            : 'End call',
                        destructive: true,
                        onPressed: () => bloc.add(const CallEndRequested()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.session,
    required this.peerName,
    required this.lowBalanceAt,
    required this.frozenElapsed,
    required this.onElapsed,
  });

  final CallState state;
  final CallSession session;
  final String peerName;
  final DateTime? lowBalanceAt;
  final int frozenElapsed;
  final ValueChanged<int> onElapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live =
        state.status == CallUiStatus.active ||
        state.status == CallUiStatus.paused;
    final white = theme.textTheme.labelLarge?.copyWith(color: Colors.white);
    return EverySecond(
      builder: (context, now) {
        final paused = state.status == CallUiStatus.paused || state.reconnecting;
        final started = session.startedAt;
        // Display clock anchored on the server's start time; frozen while
        // paused. Billing figures are the server's billedSeconds.
        var elapsed = frozenElapsed;
        if (!paused) {
          elapsed = started == null
              ? session.billedSeconds
              : now.difference(started).inSeconds.clamp(0, 1 << 31);
          onElapsed(elapsed);
        }
        final window = session.moderationWindowEndsAt;
        final safety = live && window != null && now.isBefore(window);
        final low = state.lowBalanceSecondsRemaining;
        final lowLeft = low == null || lowBalanceAt == null
            ? null
            : (low - now.difference(lowBalanceAt!).inSeconds).clamp(0, low);
        final freeLeft = session.isFreeCall && started != null
            ? (60 - now.difference(started).inSeconds).clamp(0, 60)
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (live && lowLeft != null && session.role == CallRole.caller)
              Padding(
                padding: const EdgeInsets.only(bottom: DashuriTokens.space3),
                child: _LowBalanceBanner(seconds: lowLeft, name: peerName),
              ),
            Row(
              children: [
                UserAvatar(
                  name: peerName,
                  url: session.peer?.photoUrl,
                  radius: 20,
                ),
                const SizedBox(width: DashuriTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        session.role == CallRole.receiver
                            ? 'Customer'
                            : (session.isFreeCall ? 'Free call' : 'Video call'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (live)
                  GlassPill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          paused ? Icons.pause_rounded : Icons.circle,
                          size: paused ? 16 : 10,
                          color: paused ? Colors.white : DashuriTokens.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DashuriFormat.duration(elapsed),
                          style: white?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (live) ...[
              const SizedBox(height: DashuriTokens.space3),
              Wrap(
                spacing: DashuriTokens.space2,
                runSpacing: DashuriTokens.space2,
                children: [
                  if (freeLeft != null)
                    GlassPill(
                      color: DashuriTokens.gold.withValues(alpha: .85),
                      child: Text(
                        'FREE MINUTE · ${DashuriFormat.duration(freeLeft)}',
                        style: white,
                      ),
                    )
                  else if (session.role == CallRole.caller)
                    GlassPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CurrencyAmount.diamonds(
                            session.ratePerMinute,
                            suffix: '/min',
                            style: white,
                          ),
                          Text(
                            ' · ${DashuriFormat.count(session.diamondsCharged)} used',
                            style: white,
                          ),
                        ],
                      ),
                    )
                  else if (session.beansEarned != null)
                    GlassPill(
                      child: CurrencyAmount.beans(
                        session.beansEarned!,
                        suffix: ' Beans this call',
                        style: white,
                      ),
                    )
                  else
                    GlassPill(
                      child: Text(
                        'Billed ${minutesSeconds(session.billedSeconds)}',
                        style: white,
                      ),
                    ),
                  if (safety)
                    const GlassPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined),
                          SizedBox(width: 6),
                          Text('Safety check active'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LowBalanceBanner extends StatelessWidget {
  const _LowBalanceBanner({required this.seconds, required this.name});

  final int seconds;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(DashuriTokens.space3),
        decoration: BoxDecoration(
          color: DashuriTokens.warning,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                '$seconds',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: DashuriTokens.warning,
                ),
              ),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$seconds seconds of talk time left',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'The call ends automatically when your balance runs out. '
                    'You can top up in your wallet after the call.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay({required this.state, required this.session});

  final CallState state;
  final CallSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringing = state.status == CallUiStatus.ringing;
    final name = session.peerName.isEmpty ? 'the host' : session.peerName;
    return ColoredBox(
      color: Colors.black.withValues(alpha: .45),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageGutter,
              vertical: 120,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  name: name,
                  url: session.peer?.photoUrl,
                  radius: 56,
                ),
                const SizedBox(height: DashuriTokens.space5),
                Text(
                  ringing ? 'Ringing…' : 'Connecting securely…',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DashuriTokens.space3),
                if (!ringing) ...[
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: DashuriTokens.space3),
                ],
                Text(
                  session.isFreeCall
                      ? 'Your free minute starts when you are both connected.'
                      : session.role == CallRole.caller
                      ? (ringing
                            ? 'Billing starts when you are both connected'
                            : "You haven't been charged yet")
                      : 'Connecting to $name',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (ringing && !session.isFreeCall) ...[
                  const SizedBox(height: DashuriTokens.space3),
                  GlassPill(
                    child: CurrencyAmount.diamonds(
                      session.ratePerMinute,
                      suffix: ' / min',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconnectingOverlay extends StatelessWidget {
  const _ReconnectingOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paused =
        context.select<CallBloc, bool>(
          (b) => b.state.status == CallUiStatus.paused,
        );
    return ColoredBox(
      color: Colors.black.withValues(alpha: .6),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.pageGutter),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 40),
                const SizedBox(height: DashuriTokens.space3),
                Text(
                  'Connection lost',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  'Trying to reconnect…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                if (paused) ...[
                  const SizedBox(height: DashuriTokens.space4),
                  const GlassPill(
                    child: Text(
                      "Billing is paused. You won't be charged while you're "
                      'disconnected.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
