import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../widgets/host_widgets.dart';

/// H20 payout method (RoutePaths.hostPayoutMethod). No payout provider has
/// been chosen (D-19), so there is nothing to save yet: this page explains
/// the rules and does not collect account details.
class HostPayoutMethodPage extends StatelessWidget {
  const HostPayoutMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payout method')),
      body: HostFormBody(
        children: [
          const SizedBox(height: DashuriTokens.space4),
          const HostHeroIcon(icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: DashuriTokens.space5),
          Text(
            'Available after payouts launch',
            style: theme.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DashuriTokens.space2),
          Text(
            "You'll be able to add a UPI ID or bank account here when "
            'withdrawals open. There is nothing to set up today, and your '
            'Beans keep growing in the meantime.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DashuriTokens.space5),
          const HostNotice(
            icon: Icons.verified_user_outlined,
            message:
                "Payouts can only go to an account in your own name. We can't "
                "pay to family or friends' accounts. We'll check the name "
                'against your verified ID before the first payout.',
          ),
        ],
      ),
      bottomNavigationBar: HostBottomBar(
        children: [
          OutlinedButton(
            onPressed: () => context.go(RoutePaths.hostEarnings),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(DashuriTokens.buttonHeight),
            ),
            child: const Text('Back to earnings'),
          ),
        ],
      ),
    );
  }
}
