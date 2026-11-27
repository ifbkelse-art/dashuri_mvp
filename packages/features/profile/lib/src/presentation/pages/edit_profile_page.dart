import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_profile_cubit.dart';
import '../../application/profile_failure.dart';
import '../../domain/entities/profile.dart';

/// S02 edit profile: photo, display name, bio, languages, gender (private)
/// and city. Contact details in text are rejected inline.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _fill(EditProfileState s) {
    _name.text = s.name;
    _bio.text = s.bio;
    _filled = true;
  }

  Future<void> _pickCity(BuildContext context) async {
    final cubit = context.read<EditProfileCubit>();
    final result = await context.push<Object?>(RoutePaths.cityPicker);
    if (result != null) await cubit.reloadCity();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditProfileCubit, EditProfileState>(
      listenWhen: (a, b) =>
          (a.status != b.status && b.status == EditProfileStatus.ready) ||
          (!a.saved && b.saved) ||
          (!a.photoSubmitted && b.photoSubmitted) ||
          (b.photoFailure != null && a.photoFailure != b.photoFailure),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (!_filled && state.status == EditProfileStatus.ready) _fill(state);
        if (state.saved) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Profile saved')),
          );
        } else if (state.photoSubmitted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Photo uploaded. It will appear once our team has reviewed it.',
              ),
            ),
          );
        } else if (state.photoFailure != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureMessage(state.photoFailure!))),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<EditProfileCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit profile'),
            actions: [
              if (state.status == EditProfileStatus.ready)
                TextButton(
                  onPressed: state.canSave ? cubit.save : null,
                  child: state.saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
            ],
          ),
          body: switch (state.status) {
            EditProfileStatus.loading => const LoadingView(),
            EditProfileStatus.failed => ErrorStateView(
              title: "Couldn't load your profile",
              message: failureMessage(state.loadFailure!),
              onRetry: cubit.load,
            ),
            EditProfileStatus.ready => _form(context, state),
          },
        );
      },
    );
  }

  Widget _form(BuildContext context, EditProfileState state) {
    final theme = Theme.of(context);
    final cubit = context.read<EditProfileCubit>();
    final p = state.original!;
    final rejected = state.rejectedField;
    final nameRejected = rejected == 'display_name' || rejected == 'any';
    final bioRejected = rejected == 'bio';
    final otherError = state.saveFailure != null && rejected == null
        ? failureMessage(state.saveFailure!)
        : null;
    return FormPageBody(
      children: [
        const SizedBox(height: DashuriTokens.space4),
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  UserAvatar(name: state.name, url: p.photoUrl, radius: 52),
                  if (state.photoUploadAvailable)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Change photo',
                        onPressed: state.uploadingPhoto
                            ? null
                            : cubit.pickAndUploadPhoto,
                        icon: state.uploadingPhoto
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                state.photoUploadAvailable
                    ? 'Photos are reviewed before they appear.'
                    : 'Photo upload is not available in this version of '
                          'the app yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: DashuriTokens.space6),
        if (otherError != null) ...[
          InfoBanner(tone: InfoBannerTone.error, message: otherError),
          const SizedBox(height: DashuriTokens.space4),
        ],
        TextField(
          controller: _name,
          onChanged: cubit.nameChanged,
          maxLength: displayNameMaxLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Display name',
            helperText: 'Use your first name or a nickname.',
            errorMaxLines: 3,
            errorText: nameRejected
                ? profileTextRejectedMessage
                : state.nameValid
                ? null
                : 'Use $displayNameMinLength–$displayNameMaxLength characters.',
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        TextField(
          controller: _bio,
          onChanged: cubit.bioChanged,
          maxLength: bioMaxLength,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'About you',
            alignLabelWithHint: true,
            errorMaxLines: 3,
            errorText: bioRejected ? profileTextRejectedMessage : null,
          ),
        ),
        const SizedBox(height: DashuriTokens.space4),
        Text('Languages you speak', style: theme.textTheme.titleMedium),
        const SizedBox(height: DashuriTokens.space2),
        Wrap(
          spacing: DashuriTokens.space2,
          runSpacing: DashuriTokens.space2,
          children: [
            for (final entry in profileLanguages.entries)
              FilterChip(
                label: Text(entry.value),
                selected: state.languages.contains(entry.key),
                onSelected: (_) => cubit.toggleLanguage(entry.key),
              ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space5),
        DropdownButtonFormField<Gender>(
          initialValue: state.gender,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Gender · private',
            helperText: 'Never shown on your profile.',
          ),
          items: [
            for (final g in Gender.values)
              DropdownMenuItem(value: g, child: Text(g.label)),
          ],
          onChanged: (g) {
            if (g != null) cubit.genderChanged(g);
          },
        ),
        const SizedBox(height: DashuriTokens.space4),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.location_on_outlined,
              title: 'City',
              value: state.city?.name ?? 'Not set',
              onTap: () => _pickCity(context),
            ),
            if (state.city != null)
              SettingsTile(
                icon: Icons.location_off_outlined,
                title: 'Remove city',
                onTap: state.saving ? null : cubit.clearCity,
              ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space4),
        Text(
          'Your phone number and date of birth cannot be changed here. '
          'Contact support to correct your date of birth.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
