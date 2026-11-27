import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/call_bloc.dart';
import '../../application/gift_celebration_cubit.dart';
import '../../application/gift_sheet_bloc.dart';
import '../../domain/entities/call_session.dart';
import '../gifts/gift_celebration_overlay.dart';
import '../gifts/gift_sheet.dart';
import '../in_call_chat.dart';
import '../video/video_view_factory.dart';
import '../widgets/call_widgets.dart';

/// The call screen for both sides: V02 ringing, V03 connecting, V04/V17
/// active, V05 low balance, V07 interrupted, V15 free minute and V16
/// incoming. Every billing figure shown comes from the server session.
///
/// EXPERIMENT — with [chat], a live call gets a chat control that opens the
/// pair's conversation in a panel over the video. The panel is plain UI on
/// this page: it never sends call events, so it cannot end, pause or bill.
///
/// Gifts (DASHURI_GIFTS_ENABLED): with [giftsEnabled], the route provides a
/// [GiftSheetBloc] and a [GiftCelebrationCubit]. The customer gets a Gift
/// control in place of the former camera on/off control (the camera stays
/// on for the whole call; the Stream engine still owns its lifecycle);
/// both sides see server-confirmed gift celebrations.
class CallPage extends StatefulWidget {
  const CallPage({
    required this.views,
    super.key,
    this.manageSystemUi = true,
    this.chat,
    this.giftsEnabled = false,
    this.incoming = false,
  });

  final VideoViewFactory views;

  /// Opened for a ring to this user (the host side). Decides where the
  /// screen goes when it closes before a call session could be loaded.
  final bool incoming;

  /// Full-screen (immersive) while the page is open.
  final bool manageSystemUi;

  /// In-call chat (null: no chat control).
  final InCallChat? chat;

  /// Gift control and celebrations (blocs provided by the route).
  final bool giftsEnabled;

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  int? _lowBalanceValue;
  DateTime? _lowBalanceAt;
  int _frozenElapsed = 0;
  InCallChatSession? _chat;
  bool _chatOpen = false;
  bool _giftsStarted = false;
  bool _wasReconnecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.manageSystemUi) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    // The listener only sees changes; pick up a call that is already live.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncChat(context.read<CallBloc>().state);
      _syncGifts(context.read<CallBloc>().state);
    });
  }

  @override
  void dispose() {
    unawaited(_chat?.close());
    if (widget.manageSystemUi) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  static bool _isLive(CallState s) =>
      s.status == CallUiStatus.active || s.status == CallUiStatus.paused;

  /// Opens the chat session once the call is live (billing started, so the
  /// peer counts as a call partner); closes the panel when the call ends.
  void _syncChat(CallState s) {
    final session = s.session;
    if (_chat == null && widget.chat != null && session != null && _isLive(s)) {
      setState(() {
        _chat = widget.chat!.open(
          callId: session.callId,
          peerUserId: session.peerUserId,
          peerName: session.peerName,
        );
      });
    }
    if (_chatOpen && !_isLive(s)) _setChatOpen(false);
  }

  /// Starts gift celebrations once the call is live; keeps the gift sheet's
  /// eligibility in step with the call; after a reconnect, fetches gifts
  /// missed meanwhile from the server (no replay of older ones).
  void _syncGifts(CallState s) {
    if (!widget.giftsEnabled) return;
    final session = s.session;
    if (session == null) return;
    final celebrations = context.read<GiftCelebrationCubit>();
    if (!_giftsStarted && _isLive(s)) {
      _giftsStarted = true;
      unawaited(celebrations.start(session.callId));
    }
    if (_wasReconnecting && !s.reconnecting && _giftsStarted) {
      unawaited(celebrations.resync());
    }
    _wasReconnecting = s.reconnecting;
    final eligible = s.status == CallUiStatus.active;
    final sheet = context.read<GiftSheetBloc>();
    if (sheet.state.callEligible != eligible) {
      sheet.add(GiftCallEligibilityChanged(eligible: eligible));
    }
  }

  Future<void> _openGifts(BuildContext context, CallSession session) =>
      showGiftSheet(
        context,
        bloc: context.read<GiftSheetBloc>(),
        callId: session.callId,
        recipientUserId: session.peerUserId,
        recipientName: session.peerName,
        onOpenWallet: () => unawaited(context.push(RoutePaths.wallet)),
      );

  void _setChatOpen(bool open) {
    if (_chatOpen == open) return;
    if (!open) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _chatOpen = open);
    _chat?.setVisible(open);
  }

  /// Where to go when the call screen closes without a session: a host
  /// answering a ring goes back to Host Home (still in host mode), a
  /// customer to Discovery. It used to be Discovery for both, which dropped
  /// a host into the customer shell (2026-11-27).
  String get _home =>
      widget.incoming ? RoutePaths.hostDashboard : RoutePaths.discovery;

  void _onState(BuildContext context, CallState s) {
    _syncChat(s);
    _syncGifts(s);
    if (s.status != CallUiStatus.ended) return;
    final session = s.session;
    final router = GoRouter.of(context);
    if (session == null) {
      router.go(
        s.requestedEndReason == 'declined'
            ? '${RoutePaths.hostDashboard}?after=declined'
            : _home,
      );
      return;
    }
    final receiverNoCall =
        session.role == CallRole.receiver &&
        (session.phase == CallPhase.declined ||
            session.phase == CallPhase.missed ||
            s.requestedEndReason == 'declined');
    if (receiverNoCall) {
      // Back to Host Home (still online); it says what happened.
      final missed = session.phase == CallPhase.missed;
      router.go(
        '${RoutePaths.hostDashboard}?after=${missed ? 'missed' : 'declined'}',
      );
      return;
    }
    router.go(
      RoutePaths.withParams(RoutePaths.callSummary, {'callId': session.callId}),
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

  /// Anchors the visual low-balance countdown on when the warning arrived.
  void _trackLowBalance(CallState s) {
    final v = s.lowBalanceSecondsRemaining;
    if (v != null && v != _lowBalanceValue) {
      _lowBalanceValue = v;
      _lowBalanceAt = DateTime.now().toUtc();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: DashuriTheme.dark(),
    child: widget.giftsEnabled
        ? BlocListener<GiftSheetBloc, GiftSheetState>(
            // Only the server's receipt celebrates a sent gift.
            listenWhen: (a, b) =>
                b.sentCount != a.sentCount && b.lastReceipt != null,
            listener: (context, s) => context
                .read<GiftCelebrationCubit>()
                .offer(s.lastReceipt!.event),
            child: _consumer(),
          )
        : _consumer(),
  );

  Widget _consumer() => BlocConsumer<CallBloc, CallState>(
    listener: _onState,
    builder: (context, s) => PopScope(
      canPop:
          s.status == CallUiStatus.failed ||
          s.status == CallUiStatus.ended ||
          s.status == CallUiStatus.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back closes the chat panel first; it never ends the call.
        if (_chatOpen) {
          _setChatOpen(false);
        } else {
          unawaited(_confirmLeave(context));
        }
      },
      child: Scaffold(
        backgroundColor: DashuriTokens.neutral950,
        // The video stays full-screen; the call chrome handles the keyboard.
        resizeToAvoidBottomInset: false,
        body: _body(context, s),
      ),
    ),
  );

  Widget _body(BuildContext context, CallState s) {
    _trackLowBalance(s);
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
              ? context.go(_home)
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
          chat: _isLive(s) ? _chat : null,
          chatOpen: _chatOpen,
          onChatOpen: _setChatOpen,
          giftsEnabled: widget.giftsEnabled,
          onGift: () => unawaited(_openGifts(context, session)),
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
            // Full width as well as full height: without minWidth the column
            // is only as wide as its widest line and sits at the left edge.
            constraints: BoxConstraints(
              minHeight: c.maxHeight,
              minWidth: c.maxWidth,
            ),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (session.peer?.isVerified ?? false) ...[
                            const SizedBox(width: DashuriTokens.space2),
                            const VerifiedHostBadge(
                              compact: true,
                              size: 26,
                              onMedia: true,
                            ),
                          ],
                        ],
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
                          onPressed: () => _withHaptic(
                            () =>
                                bloc.add(CallIncomingDeclined(session.callId)),
                          ),
                        ),
                      ),
                      _Labeled(
                        label: 'Accept',
                        child: Material(
                          color: DashuriTokens.success,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _withHaptic(
                              () => bloc.add(
                                CallIncomingAccepted(session.callId),
                              ),
                            ),
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
    required this.chat,
    required this.chatOpen,
    required this.onChatOpen,
    this.giftsEnabled = false,
    this.onGift,
  });

  final CallState state;
  final CallSession session;
  final VideoViewFactory views;
  final DateTime? lowBalanceAt;
  final int frozenElapsed;
  final ValueChanged<int> onElapsed;
  final VoidCallback onReport;
  final InCallChatSession? chat;
  final bool chatOpen;
  final ValueChanged<bool> onChatOpen;
  final bool giftsEnabled;
  final VoidCallback? onGift;

  /// Height of the call screen (without keyboard) below which the top bar
  /// gives way to the chat while typing.
  static const _roomyHeight = 460.0;

  bool get _live =>
      state.status == CallUiStatus.active ||
      state.status == CallUiStatus.paused;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CallBloc>();
    final peerName = session.peerName.isEmpty
        ? (session.role == CallRole.caller ? 'Host' : 'Customer')
        : session.peerName;
    final avatar = Center(
      child: UserAvatar(
        name: peerName,
        url: session.peer?.photoUrl,
        radius: 56,
      ),
    );
    final isWaiting = !_live;
    final chat = this.chat;
    final showChat = chat != null && chatOpen;
    return LayoutBuilder(
      builder: (context, c) {
        final area = c.biggest;
        final padding = MediaQuery.paddingOf(context);
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        final typing = showChat && keyboard > 0;
        final showTopBar = !typing || area.height - keyboard >= _roomyHeight;
        final chromeHeight =
            area.height -
            keyboard -
            padding.top -
            (keyboard == 0 ? padding.bottom : 0);
        final topBarMax =
            (chromeHeight *
                    (!showChat
                        ? .6
                        : chromeHeight < 520
                        ? .25
                        : .35))
                .clamp(0.0, double.infinity);
        final controls = CallControlsBar(
          // Report first and End last: the two most consequential controls
          // are as far apart as possible (End is not confirmed, because
          // billing is per second; Report asks to confirm). Phase 9.
          children: [
            RoundControl(
              icon: Icons.flag_rounded,
              label: 'Report',
              onPressed: onReport,
            ),
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
            // The former camera on/off control: the customer's Gift
            // control. Hosts have no control here (they never send gifts).
            if (giftsEnabled && session.role == CallRole.caller)
              RoundControl(
                icon: Icons.card_giftcard_rounded,
                label: 'Send a gift',
                onPressed: state.status == CallUiStatus.active ? onGift : null,
              ),
            if (chat != null)
              ValueListenableBuilder<int>(
                valueListenable: chat.unseen,
                builder: (context, unseen, _) => RoundControl(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: chatOpen ? 'Close chat' : 'Open chat',
                  active: chatOpen,
                  badgeCount: chatOpen ? 0 : unseen,
                  onPressed: () => onChatOpen(!chatOpen),
                ),
              ),
            RoundControl(
              icon: Icons.call_end_rounded,
              label: state.status == CallUiStatus.ringing
                  ? 'Cancel call'
                  : 'End call',
              destructive: true,
              onPressed: () =>
                  _withHaptic(() => bloc.add(const CallEndRequested())),
            ),
          ],
        );
        return Stack(
          children: [
            Positioned.fill(
              // While ringing or connecting, _WaitingOverlay already shows
              // the avatar: a second one under it would show through as a
              // doubled circle. The video placeholder avatar is for a live
              // call whose remote camera is off.
              child: isWaiting
                  ? ColoredBox(
                      color: state.status == CallUiStatus.ringing
                          ? DashuriTokens.burgundy950
                          : DashuriTokens.neutral900,
                    )
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
            // Hidden while chatting so it never covers the conversation.
            if (_live && state.mediaJoined && !showChat)
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
            if (_live && state.reconnecting)
              const Positioned.fill(child: _ReconnectingOverlay()),
            // Gift celebrations: above the video, below the call chrome, and
            // never hit-testable.
            if (giftsEnabled && _live)
              Positioned.fill(
                child: GiftCelebrationOverlay(
                  viewerIsCustomer: session.role == CallRole.caller,
                ),
              ),
            // Top bar, chat and controls share one column, so the chat can
            // never sit under the controls or the timer, on any screen.
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: SafeArea(
                  bottom: keyboard == 0,
                  child: Column(
                    children: [
                      if (showTopBar)
                        // Capped so controls (and the chat) always fit;
                        // scrolls on short landscape screens.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: topBarMax),
                          child: SingleChildScrollView(
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
                      // Keyed: when the keyboard opens on a short screen
                      // (tablet or phone in landscape) the top bar and the
                      // controls leave this Column. Without a key the chat
                      // would be rebuilt from scratch, dropping the text
                      // field's focus and closing the keyboard again.
                      Expanded(
                        key: const ValueKey('call-chat-area'),
                        child: showChat
                            ? _ChatArea(
                                chat: chat,
                                fill: typing,
                                screenHeight: area.height,
                                onClose: () => onChatOpen(false),
                              )
                            : chat == null
                            ? const SizedBox.shrink()
                            : _ChatPreview(
                                chat: chat,
                                peerName: peerName,
                                onOpen: () => onChatOpen(true),
                              ),
                      ),
                      // While typing, the keyboard owns the bottom; closing
                      // it (or the panel) brings the controls back.
                      if (!typing)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            DashuriTokens.space3,
                            DashuriTokens.space2,
                            DashuriTokens.space3,
                            DashuriTokens.space4,
                          ),
                          child: controls,
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

/// Where the chat panel goes: bottom of the free space between the top bar
/// and the controls; right-aligned and width-capped on wide screens so the
/// video stays visible.
class _ChatArea extends StatelessWidget {
  const _ChatArea({
    required this.chat,
    required this.fill,
    required this.screenHeight,
    required this.onClose,
  });

  final InCallChatSession chat;

  /// Use all the free height (keyboard open).
  final bool fill;
  final double screenHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth >= 600;
      // The panel is see-through, but text still sits over the video: keep
      // it to the lower part of the screen so the other person's face
      // (usually upper-middle) stays clear.
      final preferred = (screenHeight * .38).clamp(200.0, 400.0);
      final height = fill ? c.maxHeight : preferred.clamp(0.0, c.maxHeight);
      return Align(
        alignment: wide ? Alignment.bottomRight : Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DashuriTokens.space3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: chat.buildPanel(context, onClose: onClose),
            ),
          ),
        ),
      );
    },
  );
}

/// A short preview of a message that arrived while the panel was closed.
/// Tap opens the chat; it hides itself after a few seconds.
class _ChatPreview extends StatefulWidget {
  const _ChatPreview({
    required this.chat,
    required this.peerName,
    required this.onOpen,
  });

  final InCallChatSession chat;
  final String peerName;
  final VoidCallback onOpen;

  static const visibleFor = Duration(seconds: 5);

  @override
  State<_ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<_ChatPreview> {
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.chat.preview.addListener(_onPreview);
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.chat.preview.removeListener(_onPreview);
    super.dispose();
  }

  void _onPreview() {
    _hide?.cancel();
    if (widget.chat.preview.value != null) {
      _hide = Timer(_ChatPreview.visibleFor, widget.chat.dismissPreview);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
    valueListenable: widget.chat.preview,
    builder: (context, text, _) {
      if (text == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DashuriTokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Semantics(
              liveRegion: true,
              button: true,
              label: 'New message from ${widget.peerName}: $text. Open chat',
              excludeSemantics: true,
              child: Material(
                color: Colors.black.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                  onTap: widget.onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(DashuriTokens.space3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: DashuriTokens.space2),
                        Expanded(
                          child: Text(
                            '${widget.peerName}: $text',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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
        final paused =
            state.status == CallUiStatus.paused || state.reconnecting;
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // Over live video: shadows keep it readable on
                              // bright frames (there is no panel behind it).
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                shadows: _videoTextShadows,
                              ),
                            ),
                          ),
                          if (session.peer?.isVerified ?? false) ...[
                            const SizedBox(width: DashuriTokens.space1),
                            const VerifiedHostBadge(
                              compact: true,
                              size: 16,
                              onMedia: true,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        session.role == CallRole.receiver
                            ? 'Customer'
                            : (session.isFreeCall ? 'Free call' : 'Video call'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xE6FFFFFF),
                          shadows: _videoTextShadows,
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
                      // White on the brand gold is 3.1:1; on goldDark 4.9:1.
                      color: DashuriTokens.goldDark,
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
          // White on the base warning orange is 3.0:1; warningText is AA.
          color: DashuriTokens.warningText,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                '$seconds',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: DashuriTokens.warningText,
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
                UserAvatar(name: name, url: session.peer?.photoUrl, radius: 56),
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
    final paused = context.select<CallBloc, bool>(
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
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 40,
                ),
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
                  Text(
                    "Billing is paused. You won't be charged while you're "
                    'disconnected.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7FD8AE),
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

/// Accept, decline and end are consequential: confirm them with a short
/// vibration (no-op where unsupported).
void _withHaptic(VoidCallback action) {
  unawaited(HapticFeedback.mediumImpact());
  action();
}

/// Shadows for text drawn straight on video.
const _videoTextShadows = [
  Shadow(blurRadius: 3, color: Color(0xE6000000)),
  Shadow(blurRadius: 8, color: Color(0x99000000)),
];
