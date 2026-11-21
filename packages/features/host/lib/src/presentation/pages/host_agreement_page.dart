import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../widgets/host_widgets.dart';

/// H06 host agreement (RoutePaths.hostAgreement). The wording is a draft
/// pending legal review (D-12). The API has no agreement-acceptance endpoint
/// yet, so acceptance gates the flow on this device only.
class HostAgreementPage extends StatefulWidget {
  const HostAgreementPage({super.key, this.readOnly = false});

  /// Opened from settings: show the text without the accept action.
  final bool readOnly;

  @override
  State<HostAgreementPage> createState() => _HostAgreementPageState();
}

class _HostAgreementPageState extends State<HostAgreementPage> {
  bool _accepted = false;

  static const _points = [
    (
      Icons.work_outline_rounded,
      'Independent creator',
      "You're not an employee. You choose when and whether to work.",
    ),
    (
      Icons.visibility_off_outlined,
      'Content rules',
      'No nudity or sexual content. Calls are safety-checked; reports are investigated.',
    ),
    (
      null,
      'How Beans work',
      'Every 16,670 Diamonds a customer spends with you = 10,000 Beans. '
          '200 Beans = ₹1. Beans never expire.',
    ),
    (
      Icons.event_available_outlined,
      'Withdrawals',
      'Beans become withdrawable 7 days after you earn them. Weekly payouts, '
          'minimum ₹500, once payouts launch.',
    ),
    (
      Icons.receipt_long_outlined,
      'Tax',
      'Tax may be deducted from payouts as required by law. PAN is mandatory.',
    ),
    (
      Icons.storage_outlined,
      'Your data',
      'We process your ID and call data to verify you, pay you and keep calls safe.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: widget.readOnly ? const Text('Host agreement') : null,
        bottom: widget.readOnly ? null : const HostStepProgress(step: 2),
      ),
      body: HostFormBody(
        children: [
          if (!widget.readOnly) ...[
            Text('Host agreement', style: theme.textTheme.displaySmall),
            const SizedBox(height: DashuriTokens.space1),
            Text(
              'The key points, in plain words.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: DashuriTokens.space4),
          ],
          const HostNotice(
            icon: Icons.edit_note_rounded,
            tone: StatusTone.warning,
            message:
                'Draft — pending legal review. This summary may change before launch.',
          ),
          const SizedBox(height: DashuriTokens.space4),
          for (final (icon, title, body) in _points)
            Padding(
              padding: const EdgeInsets.only(bottom: DashuriTokens.space3),
              child: HostCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: icon == null
                          ? const BeanIcon(size: 20)
                          : Icon(icon, size: 22),
                    ),
                    const SizedBox(width: DashuriTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(body, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.readOnly
          ? null
          : HostBottomBar(
              children: [
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "I've read and accept the Host Agreement (draft)",
                  ),
                ),
                PrimaryButton(
                  label: 'Accept and continue',
                  onPressed: _accepted
                      ? () => context.go(RoutePaths.hostVerification)
                      : null,
                ),
              ],
            ),
    );
  }
}
