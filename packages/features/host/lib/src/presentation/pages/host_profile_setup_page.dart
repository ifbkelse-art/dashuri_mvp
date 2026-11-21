import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_profile_setup_cubit.dart';
import '../../domain/entities/host_profile.dart';
import '../../domain/ports/host_photo_picker.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H09 host profile setup (RoutePaths.hostProfileSetup): display name, bio,
/// languages (PATCH /v1/me/profile) and photos (upload ticket + signed PUT).
class HostProfileSetupPage extends StatelessWidget {
  const HostProfileSetupPage({
    super.key,
    this.fromApplication = false,
    this.photoPicker,
  });

  /// Part of FL04: saving continues to the rate step (H10).
  final bool fromApplication;

  /// Supplied by the app; null hides "Add photo" (no picker in this build).
  final HostPhotoPicker? photoPicker;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<HostProfileSetupCubit, HostProfileSetupState>(
        listenWhen: (a, b) =>
            a.status != b.status ||
            a.failure != b.failure ||
            a.photoFailure != b.photoFailure ||
            a.photosSubmitted != b.photosSubmitted,
        listener: (context, state) {
          if (state.photoFailure != null) {
            showHostSnack(context, hostFailureMessage(state.photoFailure!));
          } else if (state.status == HostProfileSetupStatus.ready &&
              state.failure != null) {
            showHostSnack(context, hostFailureMessage(state.failure!));
          } else if (state.status == HostProfileSetupStatus.saved) {
            if (fromApplication) {
              context.go(HostPaths.inApplication(RoutePaths.hostRate));
            } else {
              showHostSnack(context, 'Profile saved');
              if (context.canPop()) context.pop();
            }
          }
        },
        buildWhen: (a, b) => a.status != b.status || a.profile != b.profile ||
            a.fieldErrors != b.fieldErrors || a.uploadingPhoto != b.uploadingPhoto ||
            a.photosSubmitted != b.photosSubmitted,
        builder: (context, state) => switch (state.status) {
          HostProfileSetupStatus.loading => Scaffold(
            appBar: AppBar(),
            body: const LoadingView(),
          ),
          HostProfileSetupStatus.loadFailed => Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              message: hostFailureMessage(state.failure!),
              onRetry: context.read<HostProfileSetupCubit>().load,
            ),
          ),
          _ => _ProfileForm(
            profile: state.profile!,
            state: state,
            fromApplication: fromApplication,
            photoPicker: photoPicker,
          ),
        },
      );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    required this.profile,
    required this.state,
    required this.fromApplication,
    required this.photoPicker,
  });

  final HostProfile profile;
  final HostProfileSetupState state;
  final bool fromApplication;
  final HostPhotoPicker? photoPicker;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.displayName,
  );
  late final TextEditingController _bio = TextEditingController(
    text: widget.profile.bio ?? '',
  );
  late final Set<String> _languages = {...widget.profile.languages};

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  String? _error(String field) => switch (widget.state.fieldErrors[field]) {
    null => null,
    'required' when field == 'languages' => 'Choose at least one language.',
    'required' => 'Enter your display name.',
    'too_long' when field == 'bio' =>
      'Keep your bio to ${HostProfileLimits.bioMax} characters.',
    'too_long' =>
      'Keep your name to ${HostProfileLimits.displayNameMax} characters.',
    _ => 'Please check this field.',
  };

  Future<void> _addPhoto() async {
    final cubit = context.read<HostProfileSetupCubit>();
    final photo = await widget.photoPicker!.pickPhoto();
    if (photo != null) await cubit.addPhoto(photo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final cubit = context.read<HostProfileSetupCubit>();
    final languages = {...hostLanguages.keys, ..._languages};
    return Scaffold(
      appBar: AppBar(
        title: widget.fromApplication ? null : const Text('Photos & bio'),
        bottom: widget.fromApplication
            ? const HostStepProgress(step: 4)
            : null,
      ),
      body: HostFormBody(
        children: [
          if (widget.fromApplication) ...[
            Text('Make your profile shine', style: theme.textTheme.displaySmall),
            const SizedBox(height: DashuriTokens.space4),
          ],
          Text('Photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: DashuriTokens.space2),
          _Photos(
            urls: widget.profile.photoUrls,
            submitted: state.photosSubmitted,
            uploading: state.uploadingPhoto,
            canAdd:
                widget.photoPicker != null &&
                state.photoCount < HostProfileLimits.maxPhotos,
            onAdd: _addPhoto,
          ),
          const SizedBox(height: DashuriTokens.space2),
          Text(
            widget.photoPicker == null
                ? "Adding photos isn't available in this version of the app yet. "
                      'Photos you already have are shown above.'
                : 'Up to 6 photos. The first is your cover in Discover. New '
                      'photos stay private until our team approves them.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: DashuriTokens.space5),
          TextField(
            controller: _name,
            maxLength: HostProfileLimits.displayNameMax,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Display name',
              errorText: _error('display_name'),
            ),
          ),
          const SizedBox(height: DashuriTokens.space3),
          TextField(
            controller: _bio,
            maxLength: HostProfileLimits.bioMax,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'About you',
              helperText: 'No phone numbers, links or social handles.',
              errorText: _error('bio'),
            ),
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text('Languages you speak', style: theme.textTheme.titleMedium),
          const SizedBox(height: DashuriTokens.space2),
          Wrap(
            spacing: DashuriTokens.space2,
            runSpacing: DashuriTokens.space2,
            children: [
              for (final code in languages)
                FilterChip(
                  label: Text(languageName(code)),
                  selected: _languages.contains(code),
                  onSelected: (on) => setState(
                    () => on ? _languages.add(code) : _languages.remove(code),
                  ),
                ),
            ],
          ),
          if (_error('languages') != null)
            Padding(
              padding: const EdgeInsets.only(top: DashuriTokens.space2),
              child: Text(
                _error('languages')!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: HostBottomBar(
        children: [
          PrimaryButton(
            label: widget.fromApplication ? 'Continue to rate' : 'Save',
            busy: state.status == HostProfileSetupStatus.saving,
            onPressed: () => cubit.save(
              displayName: _name.text,
              bio: _bio.text,
              languages: _languages.toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({
    required this.urls,
    required this.submitted,
    required this.uploading,
    required this.canAdd,
    required this.onAdd,
  });

  final List<String> urls;
  final int submitted;
  final bool uploading;
  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(Widget child, {String? label}) => ClipRRect(
      borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
      child: Container(
        width: 96,
        height: 120,
        color: scheme.surfaceContainer,
        child: Semantics(label: label, child: child),
      ),
    );
    return Wrap(
      spacing: DashuriTokens.space2,
      runSpacing: DashuriTokens.space2,
      children: [
        for (var i = 0; i < urls.length; i++)
          tile(
            Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
            label: i == 0 ? 'Cover photo' : 'Photo ${i + 1}',
          ),
        for (var i = 0; i < submitted; i++)
          tile(
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top_rounded),
                SizedBox(height: 4),
                Text('In review', textAlign: TextAlign.center),
              ],
            ),
            label: 'Photo in review',
          ),
        if (uploading)
          tile(
            const Center(child: CircularProgressIndicator()),
            label: 'Uploading photo',
          )
        else if (canAdd)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
            child: tile(
              Icon(Icons.add_a_photo_outlined, color: scheme.primary),
              label: 'Add photo',
            ),
          ),
        if (urls.isEmpty && submitted == 0 && !canAdd && !uploading)
          tile(
            Icon(Icons.person_outline_rounded, color: scheme.onSurfaceVariant),
            label: 'No photos yet',
          ),
      ],
    );
  }
}
