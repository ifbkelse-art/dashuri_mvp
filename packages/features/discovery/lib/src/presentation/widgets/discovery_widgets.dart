import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/discovery_filter.dart';
import '../../domain/entities/host_card.dart';

/// Plain-language copy for discovery failures.
String discoveryFailureMessage(Failure f) => switch (f) {
  NetworkFailure() => "You're offline. Check your connection and try again.",
  NotFoundFailure() => 'This profile is no longer available.',
  UnauthenticatedFailure() => 'Your session has ended. Please sign in again.',
  _ => "We couldn't load hosts right now. Please try again.",
};

/// Reads the City popped by the city picker (`RoutePaths.cityPicker`,
/// owned by FE-core). Accepts a `Map` with `id`/`name` (and optional
/// `state`) or any object exposing `id` and `name` String getters.
City? cityFromPickerResult(Object? result) {
  if (result == null) return null;
  if (result is City) return result;
  if (result is Map) {
    final id = result['id'], name = result['name'], state = result['state'];
    return id is String && name is String
        ? City(id: id, name: name, state: state is String ? state : null)
        : null;
  }
  try {
    // ignore: avoid_dynamic_calls
    final Object? id = (result as dynamic).id;
    // ignore: avoid_dynamic_calls
    final Object? name = (result as dynamic).name;
    return id is String && name is String ? City(id: id, name: name) : null;
  } on NoSuchMethodError {
    return null;
  }
}

String hostTitle(HostCard h) =>
    h.age == null ? h.displayName : '${h.displayName}, ${h.age}';

(String, StatusTone) availabilityLabel(HostAvailability a) => switch (a) {
  HostAvailability.available => ('Online', StatusTone.online),
  HostAvailability.busy => ('In a call', StatusTone.busy),
  HostAvailability.offline => ('Offline', StatusTone.offline),
};

/// Host photo with a calm fallback (initials on a burgundy gradient).
class HostPhoto extends StatelessWidget {
  const HostPhoto({required this.name, super.key, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DashuriTokens.burgundy400, DashuriTokens.burgundy900],
        ),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: DashuriText.display(56, 60, Colors.white),
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// C01 grid card: photo, status, verified, name and age, languages, rate.
class HostGridCard extends StatelessWidget {
  const HostGridCard({required this.host, required this.onTap, super.key});

  final HostCard host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, tone) = availabilityLabel(host.status);
    final white = theme.textTheme.titleMedium?.copyWith(color: Colors.white);
    return Opacity(
      opacity: host.status == HostAvailability.available ? 1 : .7,
      child: Semantics(
        button: true,
        label:
            '${hostTitle(host)}, $label, ${host.ratePerMinute} Diamonds '
            'per minute'
            '${host.arrivalPhoto == null ? '' : ', has a recent photo'}',
        excludeSemantics: true,
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HostPhoto(name: host.displayName, url: host.photoUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [.45, 1],
                      colors: [Colors.transparent, Color(0xCC110E0D)],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: StatusTag(label: label, tone: tone, dot: true),
                        ),
                      ),
                      const Spacer(),
                      if (host.isVerified)
                        const VerifiedHostBadge(
                          compact: true,
                          size: 22,
                          onMedia: true,
                        ),
                    ],
                  ),
                ),
                if (host.arrivalPhoto != null)
                  Positioned(
                    right: 10,
                    top: 44,
                    child: ArrivalPhotoInset(photo: host.arrivalPhoto!),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hostTitle(host),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: white,
                      ),
                      if (host.languages.isNotEmpty)
                        Text(
                          host.languages.map(languageName).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: CurrencyAmount.diamonds(
                              host.ratePerMinute,
                              suffix: ' / min',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// C06 skeleton tile mirroring the card geometry, with a soft pulse.
class HostCardSkeleton extends StatefulWidget {
  const HostCardSkeleton({super.key});

  @override
  State<HostCardSkeleton> createState() => _HostCardSkeletonState();
}

class _HostCardSkeletonState extends State<HostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: .5, end: 1).animate(_c),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// "Captured 3 minutes ago" — an honest age for an arrival photo. Never
/// "live": the photo was taken when the host came online.
String arrivalCapturedAgo(DateTime capturedAt, DateTime now) {
  final d = now.difference(capturedAt);
  if (d.inSeconds < 60) return 'Captured just now';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return 'Captured $m minute${m == 1 ? '' : 's'} ago';
  }
  final h = d.inHours;
  return 'Captured $h hour${h == 1 ? '' : 's'} ago';
}

/// Compact form for grid cards: "3 min ago".
String arrivalShortAgo(DateTime capturedAt, DateTime now) {
  final d = now.difference(capturedAt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}

/// Small inset on a grid card: the arrival photo with its age.
class ArrivalPhotoInset extends StatelessWidget {
  const ArrivalPhotoInset({required this.photo, super.key, this.now});

  final HostArrivalPhoto photo;

  /// For tests; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = now ?? DateTime.now().toUtc();
    return Semantics(
      label: 'Recent photo. ${arrivalCapturedAgo(photo.capturedAt, t)}.',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  photo.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: DashuriTokens.neutral700),
                ),
              ),
            ),
            const SizedBox(height: 2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  arrivalShortAgo(photo.capturedAt, t),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
