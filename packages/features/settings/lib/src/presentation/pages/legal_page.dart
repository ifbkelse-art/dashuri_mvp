import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../widgets/legal_texts.dart';
import '../widgets/settings_list.dart';

/// S08 legal list, or one document when `?doc=<id>` is given
/// (terms, privacy, community, child_safety, refunds, grievance).
/// Every document is marked as a draft pending legal review (D-12).
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, this.docId});

  final String? docId;

  static const _icons = {
    'terms': Icons.description_outlined,
    'privacy': Icons.lock_outline,
    'community': Icons.groups_outlined,
    'child_safety': Icons.child_care_outlined,
    'refunds': Icons.diamond_outlined,
    'grievance': Icons.gavel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final doc = legalDocumentById(docId);
    if (doc != null) return _DocumentView(doc: doc);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: SettingsList(
        children: [
          const SizedBox(height: DashuriTokens.space4),
          const _DraftBanner(),
          const SizedBox(height: DashuriTokens.space2),
          SettingsGroup(
            children: [
              for (final d in legalDocuments.where((d) => d.id != 'grievance'))
                SettingsTile(
                  icon: _icons[d.id] ?? Icons.description_outlined,
                  title: d.title,
                  onTap: () => context.push('${RoutePaths.legal}?doc=${d.id}'),
                ),
            ],
          ),
          SettingsGroup(
            title: 'Grievance redressal',
            children: [
              SettingsTile(
                icon: Icons.gavel_outlined,
                title: 'Grievance Officer',
                subtitle:
                    'For complaints under the IT Rules. We acknowledge within '
                    '24 hours.',
                onTap: () => context.push('${RoutePaths.legal}?doc=grievance'),
              ),
              SettingsTile(
                icon: Icons.mail_outline,
                title: 'Raise a complaint',
                onTap: () => context.push(RoutePaths.helpSupport),
              ),
            ],
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(
            'BK Enterprises · Dashuri',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  const _DraftBanner();

  @override
  Widget build(BuildContext context) => const InfoBanner(
    tone: InfoBannerTone.warning,
    icon: Icons.edit_note,
    message:
        '$legalDraftNotice. These documents are placeholders and are not '
        'yet legally binding.',
  );
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.doc});

  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SettingsList(
        children: [
          const SizedBox(height: DashuriTokens.space4),
          const _DraftBanner(),
          for (final (heading, body) in doc.sections) ...[
            const SizedBox(height: DashuriTokens.space5),
            Semantics(
              header: true,
              child: Text(heading, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: DashuriTokens.space2),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
          if (doc.id == 'grievance') ...[
            const SizedBox(height: DashuriTokens.space6),
            OutlinedButton(
              onPressed: () => context.push(RoutePaths.helpSupport),
              child: const Text('Raise a complaint'),
            ),
          ],
        ],
      ),
    );
  }
}
