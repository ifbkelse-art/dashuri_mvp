import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

/// Plain-language copy for call failures (design V01–V18).
String callFailureMessage(Failure failure) => switch (failure) {
  NetworkFailure() => "You're offline. Check your connection and try again.",
  UnauthenticatedFailure() => 'Your session has ended. Please sign in again.',
  NotFoundFailure() => 'This call or profile is no longer available.',
  _ => switch (failure.code) {
    'host_unavailable' => "This host isn't available right now.",
    'host_busy' => 'This host is in another call. Try again soon.',
    'blocked' => "You can't call this person.",
    'insufficient_diamonds' =>
      'You need at least 1 minute of balance to start a call.',
    'caller_in_call' => "You're already in another call.",
    'not_age_eligible' => 'Calls are only for verified adults (18+).',
    'account_restricted' => "Your account can't make calls right now.",
    'self_call' => "You can't call yourself.",
    'call_expired' => 'This call has already ended.',
    'illegal_call_transition' => 'This call has already changed.',
    'call_not_joinable' => 'This call can no longer be joined.',
    'video_not_configured' => "Video calling isn't set up in this build yet.",
    'video_provider_unsupported' => "This video provider isn't supported.",
    'video_credentials_invalid' ||
    'video_connect_failed' ||
    'video_join_failed' => "We couldn't connect your camera and microphone.",
    _ => 'Something went wrong. Please try again.',
  },
};

/// Rebuilds every second (display clocks only; never billing).
class EverySecond extends StatefulWidget {
  const EverySecond({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, DateTime.now().toUtc());
}

/// Frosted pill used on the call canvas (timer, rate, safety chip).
class GlassPill extends StatelessWidget {
  const GlassPill({required this.child, super.key, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? Colors.black.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white, size: 16),
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    ),
  );
}

/// Round call control (mic, camera, flip, report, end) with a label for
/// accessibility.
class RoundControl extends StatelessWidget {
  const RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
    this.destructive = false,
    this.active = false,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  /// Highlighted (e.g. microphone muted).
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? DashuriTokens.error
        : active
        ? Colors.white
        : Colors.white.withValues(alpha: .16);
    final fg = active && !destructive ? DashuriTokens.neutral900 : Colors.white;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: fg, size: size * .42),
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating control bar (DS13), width-capped on tablets.
class CallControlsBar extends StatelessWidget {
  const CallControlsBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(DashuriTokens.radiusXLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DashuriTokens.space3,
            vertical: DashuriTokens.space3,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: DashuriTokens.space3),
                  c,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Self-view tile that can be dragged to any corner (V04). Sized relative
/// to the window so it stays proportionate on phones, tablets and landscape.
class DraggableCornerTile extends StatefulWidget {
  const DraggableCornerTile({
    required this.child,
    required this.areaSize,
    super.key,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final Widget child;
  final Size areaSize;
  final double topInset;
  final double bottomInset;

  @override
  State<DraggableCornerTile> createState() => _DraggableCornerTileState();
}

class _DraggableCornerTileState extends State<DraggableCornerTile> {
  Alignment _corner = Alignment.topRight;
  Offset? _drag;

  @override
  Widget build(BuildContext context) {
    final area = widget.areaSize;
    final landscape = area.width > area.height;
    final width = (area.shortestSide * (landscape ? .34 : .28)).clamp(
      96.0,
      240.0,
    );
    final height = landscape ? width * 3 / 4 : width * 4 / 3;
    const margin = DashuriTokens.space4;
    final left = _corner.x < 0 ? margin : area.width - width - margin;
    final top = _corner.y < 0
        ? widget.topInset + margin
        : area.height - height - widget.bottomInset - margin;
    final pos = _drag ?? Offset(left, top);
    return AnimatedPositioned(
      duration: _drag == null ? DashuriTokens.motionMedium : Duration.zero,
      left: pos.dx.clamp(0, area.width - width),
      top: pos.dy.clamp(0, area.height - height),
      width: width,
      height: height,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _drag = Offset(left, top)),
        onPanUpdate: (d) => setState(() => _drag = (_drag ?? pos) + d.delta),
        onPanEnd: (_) => setState(() {
          final c = (_drag ?? pos) + Offset(width / 2, height / 2);
          _corner = Alignment(
            c.dx < area.width / 2 ? -1 : 1,
            c.dy < area.height / 2 ? -1 : 1,
          );
          _drag = null;
        }),
        child: Semantics(
          label: 'Your camera',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .7),
                  width: 2,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A label/value row used on summaries and the pre-call card.
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    required this.label,
    required this.value,
    super.key,
    this.valueColor,
  });

  final String label;
  final Widget value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: DashuriTokens.space3),
          Flexible(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.titleSmall?.copyWith(color: valueColor),
              textAlign: TextAlign.end,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(fit: BoxFit.scaleDown, child: value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "3 min 05 s" for billed durations.
String minutesSeconds(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return m == 0 ? '$s s' : '$m min ${s.toString().padLeft(2, '0')} s';
}
