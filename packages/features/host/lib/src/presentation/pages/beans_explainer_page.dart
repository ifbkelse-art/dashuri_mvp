import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/host_earnings.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H15 Beans → ₹ explainer with a display-only calculator
/// (HostPaths.beansExplainer). Payouts are calculated by the server.
class BeansExplainerPage extends StatefulWidget {
  const BeansExplainerPage({super.key, this.initialBeans = 100000});

  final int initialBeans;

  @override
  State<BeansExplainerPage> createState() => _BeansExplainerPageState();
}

class _BeansExplainerPageState extends State<BeansExplainerPage> {
  late final TextEditingController _beans = TextEditingController(
    text: '${widget.initialBeans}',
  );

  @override
  void dispose() {
    _beans.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beans = int.tryParse(_beans.text) ?? 0;
    Widget step(Widget icon, String value, String label) => Expanded(
      child: Column(
        children: [
          icon,
          const SizedBox(height: DashuriTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    const arrow = Padding(
      padding: EdgeInsets.only(top: 6),
      child: Icon(Icons.arrow_forward_rounded, size: 18),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('How Beans work')),
      body: HostFormBody(
        children: [
          HostCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                step(const DiamondIcon(size: 28), '16,670', 'Diamonds spent'),
                arrow,
                step(const BeanIcon(size: 28), '10,000', 'Beans earned'),
                arrow,
                step(
                  const Icon(Icons.currency_rupee_rounded, size: 28),
                  '₹50',
                  'Paid to you',
                ),
              ],
            ),
          ),
          const SizedBox(height: DashuriTokens.space3),
          const HostNotice(
            message:
                '200 Beans = ₹1. Beans never expire and are withdrawable 7 days '
                'after you earn them. Minimum withdrawal ₹500 (1,00,000 Beans).',
          ),
          const SectionHeader(title: 'Calculator'),
          HostCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _beans,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Beans',
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12),
                      child: BeanIcon(size: 20),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: DashuriTokens.space4),
                Text("You'd receive about", style: theme.textTheme.bodySmall),
                Text(
                  HostFormat.approxRupees(BeanRules.beansToPaise(beans)),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: DashuriTokens.space1),
                Text(
                  'Before any tax deducted at source. Display only: payouts '
                  'are calculated by Dashuri.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
