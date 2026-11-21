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
            'per minute',
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
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 22,
                          semanticLabel: 'Verified',
                        ),
                    ],
                  ),
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
                              suffix: ' /min',
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
