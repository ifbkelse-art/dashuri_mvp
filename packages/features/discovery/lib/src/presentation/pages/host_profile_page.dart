import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_profile_cubit.dart';
import '../../domain/entities/discovery_filter.dart';
import '../../domain/entities/host_card.dart';
import '../widgets/discovery_widgets.dart';

/// C07 online, C08 busy, C09 offline, with the C12 actions sheet.
class HostProfilePage extends StatelessWidget {
  const HostProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HostProfileCubit, HostProfileState>(
        builder: (context, s) => switch (s) {
          HostProfileLoading() => Scaffold(
            appBar: AppBar(),
            body: const LoadingView(),
          ),
          HostProfileFailed(:final failure) => Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              message: discoveryFailureMessage(failure),
              onRetry: () => context.read<HostProfileCubit>().load(userId),
            ),
          ),
          HostProfileLoaded() => _Loaded(state: s),
        },
      );
}

String _reportLocation(HostCard h, {bool block = false}) => Uri(
  path: RoutePaths.report,
  queryParameters: {
    'userId': h.userId,
    'name': h.displayName,
    if (block) 'mode': 'block',
  },
).toString();

Future<void> _showActions(
  BuildContext context,
  HostCard h,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: UserAvatar(name: h.displayName, url: h.photoUrl),
              title: Text(hostTitle(h)),
              subtitle: Text(
                [
                  if (h.city != null) h.city!.name,
                  if (h.isVerified) 'Verified host',
                ].join(' · '),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('Report ${h.displayName}'),
              subtitle: const Text("Tell us what happened. It's anonymous."),
              onTap: () {
                Navigator.pop(sheet);
                context.push(_reportLocation(h));
              },
            ),
            ListTile(
              iconColor: theme.colorScheme.error,
              textColor: theme.colorScheme.error,
              leading: const Icon(Icons.block_rounded),
              title: Text('Block ${h.displayName}'),
              subtitle: const Text("You won't see or hear from each other."),
              onTap: () {
                Navigator.pop(sheet);
                context.push(_reportLocation(h, block: true));
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  },
);

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final HostProfileLoaded state;

  @override
  Widget build(BuildContext context) {
    final host = state.view.profile.card;
    final gallery = _Gallery(profile: state.view.profile);
    final details = _Details(state: state);
    final actions = _Actions(host: host);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'More actions',
            onPressed: () => _showActions(context, host),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 840) {
            return Row(
              children: [
                Expanded(child: gallery),
                SizedBox(
                  width: 480,
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              DashuriTokens.space6,
                              kToolbarHeight + DashuriTokens.space4,
                              DashuriTokens.space6,
                              DashuriTokens.space4,
                            ),
                            child: details,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(DashuriTokens.space5),
                          child: actions,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final landscape = c.maxWidth > c.maxHeight;
          final photoHeight = (c.maxHeight * (landscape ? .8 : .55)).clamp(
            220.0,
            560.0,
          );
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: photoHeight, child: gallery),
                      ResponsiveCenter(
                        padding: EdgeInsets.fromLTRB(
                          context.pageGutter,
                          DashuriTokens.space5,
                          context.pageGutter,
                          DashuriTokens.space5,
                        ),
                        child: details,
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: ResponsiveCenter(
                  padding: EdgeInsets.all(context.pageGutter),
                  child: actions,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.profile});

  final HostProfile profile;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final card = widget.profile.card;
    final photos = widget.profile.gallery;
    final offline = card.status == HostAvailability.offline;
    Widget photo(String? url) => HostPhoto(name: card.displayName, url: url);
    final content = photos.length <= 1
        ? photo(photos.isEmpty ? null : photos.first)
        : PageView(
            onPageChanged: (i) => setState(() => _page = i),
            children: [for (final p in photos) photo(p)],
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (offline)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.6, 0.3, 0.1, 0, 0, //
              0.2, 0.7, 0.1, 0, 0,
              0.2, 0.3, 0.5, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: content,
          )
        else
          content,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .25],
              // 55 % black: the white app-bar icons stay ≥ 4.5:1 even
              // over a white photo (40 % gave 2.9:1).
              colors: [Color(0x8C000000), Colors.transparent],
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 64,
            right: 64,
            child: Row(
              children: [
                for (var i = 0; i < photos.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: i == _page ? 1 : .4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state});

  final HostProfileLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = state.view.profile;
    final host = profile.card;
    final (status, tone) = switch (host.status) {
      HostAvailability.available => ('Online now', StatusTone.online),
      HostAvailability.busy => ('In a call', StatusTone.busy),
      HostAvailability.offline => ('Offline', StatusTone.offline),
    };
    final approx = state.approxPaisePerMinute;
    final talk = state.talkTimeSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(hostTitle(host), style: theme.textTheme.displaySmall),
            ),
            if (host.isVerified) ...[
              const SizedBox(width: DashuriTokens.space2),
              Icon(
                Icons.verified_rounded,
                color: theme.colorScheme.primary,
                semanticLabel: 'Verified',
              ),
            ],
          ],
        ),
        const SizedBox(height: DashuriTokens.space2),
        Wrap(
          spacing: DashuriTokens.space3,
          runSpacing: DashuriTokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (host.city != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text(host.city!.name, style: theme.textTheme.bodyMedium),
                ],
              ),
            StatusTag(label: status, tone: tone, dot: true),
            StatusTag(label: 'Level ${host.level}', tone: StatusTone.neutral),
          ],
        ),
        if (host.languages.isNotEmpty) ...[
          const SizedBox(height: DashuriTokens.space4),
          Wrap(
            spacing: DashuriTokens.space2,
            runSpacing: DashuriTokens.space2,
            children: [
              for (final l in host.languages)
                Chip(
                  avatar: const Icon(Icons.translate_rounded, size: 16),
                  label: Text(languageName(l)),
                ),
            ],
          ),
        ],
        if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: DashuriTokens.space5),
          Text('About', style: theme.textTheme.titleLarge),
          const SizedBox(height: DashuriTokens.space2),
          Text(profile.bio!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: DashuriTokens.space5),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(DashuriTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: DashuriTokens.space3,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CurrencyAmount.diamonds(
                        host.ratePerMinute,
                        suffix: ' Diamonds / min',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    if (approx != null)
                      Text(
                        '≈ ${DashuriFormat.rupees(approx)}/min (approximate)',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                if (host.status == HostAvailability.available &&
                    state.view.balance != null) ...[
                  const SizedBox(height: DashuriTokens.space2),
                  Text(
                    'Your balance ${DashuriFormat.count(state.view.balance!)}'
                    '${talk == null ? '' : ' · about ${_talk(talk)} of talk time'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _talk(int seconds) {
    final m = seconds ~/ 60;
    return m >= 1 ? '$m min' : '$seconds s';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.host});

  final HostCard host;

  @override
  Widget build(BuildContext context) {
    final (label, icon, enabled) = switch (host.status) {
      HostAvailability.available => (
        'Video call',
        Icons.videocam_rounded,
        true,
      ),
      HostAvailability.busy => (
        'In a call. Try again soon',
        Icons.phone_disabled_rounded,
        false,
      ),
      HostAvailability.offline => (
        'Not available right now',
        Icons.phone_disabled_rounded,
        false,
      ),
    };
    return Row(
      children: [
        IconButton.outlined(
          tooltip: 'Message',
          onPressed: () => context.push(
            Uri(
              path: RoutePaths.withParams(RoutePaths.conversation, {
                'conversationId': 'new',
              }),
              queryParameters: {'peerUserId': host.userId},
            ).toString(),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        const SizedBox(width: DashuriTokens.space3),
        Expanded(
          child: PrimaryButton(
            label: label,
            icon: icon,
            onPressed: enabled
                ? () => context.push(
                    RoutePaths.withParams(RoutePaths.preCall, {
                      'userId': host.userId,
                    }),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
